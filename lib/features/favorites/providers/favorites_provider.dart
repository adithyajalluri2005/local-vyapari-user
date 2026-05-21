import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

import 'package:flutter/foundation.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';

class FavoritesState {
  final Set<String> productIds;
  final Set<String> shopIds;

  FavoritesState({
    required this.productIds,
    required this.shopIds,
  });

  FavoritesState copyWith({
    Set<String>? productIds,
    Set<String>? shopIds,
  }) {
    return FavoritesState(
      productIds: productIds ?? this.productIds,
      shopIds: shopIds ?? this.shopIds,
    );
  }
}

class FavoritesNotifier extends Notifier<AsyncValue<FavoritesState>> {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  List<Map<String, dynamic>> _syncQueue = [];
  bool _isSyncing = false;
  
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  AsyncValue<FavoritesState> build() {
    _init();
    return const AsyncValue.loading();
  }

  Future<void> _init() async {
    final userId = _userId;
    if (userId == null) {
      state = AsyncValue.data(FavoritesState(productIds: {}, shopIds: {}));
      return;
    }

    try {
      final snapshot = await _rtdb.ref('users/$userId/favorites').get();
      
      final productIds = <String>{};
      final shopIds = <String>{};

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        if (data['products'] != null) {
          final productsMap = data['products'] as Map<dynamic, dynamic>;
          productsMap.forEach((key, value) {
            if (value == true) productIds.add(key.toString());
          });
        }
        
        if (data['shops'] != null) {
          final shopsMap = data['shops'] as Map<dynamic, dynamic>;
          shopsMap.forEach((key, value) {
            if (value == true) shopIds.add(key.toString());
          });
        }
      }

      state = AsyncValue.data(FavoritesState(productIds: productIds, shopIds: shopIds));

      // Process any pending offline sync operations asynchronously
      _syncPendingQueue();

      // Set up a listener for real-time updates from other devices
      _rtdb.ref('users/$userId/favorites').onValue.listen((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
           state = AsyncValue.data(FavoritesState(productIds: {}, shopIds: {}));
           return;
        }

        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final newProductIds = <String>{};
        final newShopIds = <String>{};

        if (data['products'] != null) {
          (data['products'] as Map<dynamic, dynamic>).forEach((key, value) {
            if (value == true) newProductIds.add(key.toString());
          });
        }
        if (data['shops'] != null) {
          (data['shops'] as Map<dynamic, dynamic>).forEach((key, value) {
            if (value == true) newShopIds.add(key.toString());
          });
        }

        state = AsyncValue.data(FavoritesState(productIds: newProductIds, shopIds: newShopIds));
      });

    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _syncPendingQueue() async {
    if (_isSyncing) return;
    final userId = _userId;
    if (userId == null) return;

    _syncQueue = await DataCacheService.getSyncQueue();
    if (_syncQueue.isEmpty) return;

    _isSyncing = true;
    final List<Map<String, dynamic>> failedItems = [];

    for (final item in _syncQueue) {
      final type = item['type'] as String;
      final id = item['id'] as String;
      final action = item['action'] as String;

      final dbPath = type == 'product'
          ? 'users/$userId/favorites/products/$id'
          : 'users/$userId/favorites/shops/$id';

      try {
        if (action == 'add') {
          await _rtdb.ref(dbPath).set(true).timeout(const Duration(seconds: 4));
        } else {
          await _rtdb.ref(dbPath).remove().timeout(const Duration(seconds: 4));
        }
      } catch (e) {
        debugPrint('Failed to sync offline item $id: $e');
        failedItems.add(item);
      }
    }

    _syncQueue = failedItems;
    await DataCacheService.saveSyncQueue(_syncQueue);
    _isSyncing = false;
  }

  Future<void> toggleFavoriteProduct(String productId) async {
    final userId = _userId;
    if (userId == null) return;

    final currentState = state.value;
    if (currentState == null) return;

    final isFavorite = currentState.productIds.contains(productId);

    // 1. Optimistic UI update for lag-free visual response
    final updatedProducts = Set<String>.from(currentState.productIds);
    if (isFavorite) {
      updatedProducts.remove(productId);
    } else {
      updatedProducts.add(productId);
    }
    state = AsyncValue.data(currentState.copyWith(productIds: updatedProducts));

    // 2. Perform write to server
    final dbPath = 'users/$userId/favorites/products/$productId';
    try {
      if (isFavorite) {
        await _rtdb.ref(dbPath).remove().timeout(const Duration(seconds: 3));
      } else {
        await _rtdb.ref(dbPath).set(true).timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      // 3. Fallback: Save to offline sync queue if network write fails/times out
      _syncQueue.add({
        'type': 'product',
        'id': productId,
        'action': isFavorite ? 'remove' : 'add',
      });
      await DataCacheService.saveSyncQueue(_syncQueue);
      debugPrint('Offline: Saved product favorite action to sync queue.');
    }
  }

  Future<void> toggleFavoriteShop(String shopId) async {
    final userId = _userId;
    if (userId == null) return;

    final currentState = state.value;
    if (currentState == null) return;

    final isFavorite = currentState.shopIds.contains(shopId);

    // 1. Optimistic UI update
    final updatedShops = Set<String>.from(currentState.shopIds);
    if (isFavorite) {
      updatedShops.remove(shopId);
    } else {
      updatedShops.add(shopId);
    }
    state = AsyncValue.data(currentState.copyWith(shopIds: updatedShops));

    // 2. Perform write to server
    final dbPath = 'users/$userId/favorites/shops/$shopId';
    try {
      if (isFavorite) {
        await _rtdb.ref(dbPath).remove().timeout(const Duration(seconds: 3));
      } else {
        await _rtdb.ref(dbPath).set(true).timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      // 3. Fallback: Save to offline sync queue
      _syncQueue.add({
        'type': 'shop',
        'id': shopId,
        'action': isFavorite ? 'remove' : 'add',
      });
      await DataCacheService.saveSyncQueue(_syncQueue);
      debugPrint('Offline: Saved shop favorite action to sync queue.');
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, AsyncValue<FavoritesState>>(() {
  return FavoritesNotifier();
});

final favoriteProductsProvider = FutureProvider<List<Product>>((ref) async {
  final favoritesStateAsync = ref.watch(favoritesProvider);
  final favoritesState = favoritesStateAsync.value;
  if (favoritesState == null || favoritesState.productIds.isEmpty) return [];

  final List<Product> products = [];
  final rtdb = FirebaseDatabase.instance.ref();
  
  final snapshot = await rtdb.child('products').get();
  if (snapshot.exists && snapshot.value != null) {
    final Map<dynamic, dynamic> shopsProductsMap = snapshot.value as Map<dynamic, dynamic>;
    shopsProductsMap.forEach((shopIdKey, productsValue) {
      if (productsValue is Map) {
        productsValue.forEach((productIdKey, productValue) {
          final productId = productIdKey.toString();
          if (favoritesState.productIds.contains(productId) && productValue is Map) {
            products.add(Product.fromRTDB(
              productId,
              shopIdKey.toString(),
              Map<dynamic, dynamic>.from(productValue),
            ));
          }
        });
      }
    });
  }
  return products;
});

final favoriteShopsProvider = FutureProvider<List<Shop>>((ref) async {
  final favoritesStateAsync = ref.watch(favoritesProvider);
  final favoritesState = favoritesStateAsync.value;
  if (favoritesState == null || favoritesState.shopIds.isEmpty) return [];

  final List<Shop> shops = [];
  final rtdb = FirebaseDatabase.instance.ref();
  
  for (final shopId in favoritesState.shopIds) {
    final snapshot = await rtdb.child('shop/$shopId').get();
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      shops.add(Shop.fromRTDB(shopId, data));
    }
  }
  return shops;
});
