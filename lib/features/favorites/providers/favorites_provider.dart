import 'dart:async';
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
  StreamSubscription? _favoritesSubscription;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  @override
  AsyncValue<FavoritesState> build() {
    ref.onDispose(() => _favoritesSubscription?.cancel());
    _init();
    return const AsyncValue.loading();
  }

  Future<void> _init() async {
    await _favoritesSubscription?.cancel();
    _favoritesSubscription = null;

    final userId = _userId;
    if (userId == null) {
      state = AsyncValue.data(FavoritesState(productIds: {}, shopIds: {}));
      return;
    }

    try {
      final snapshot = await _rtdb.ref('users/$userId/favorites').get();

      final productIds = <String>{};
      final shopIds = <String>{};

      if (snapshot.value is Map) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        final productsMap = data['products'];
        if (productsMap is Map) {
          // value is `true` (legacy) or a shopId string (new)
          productsMap.forEach((key, value) {
            if (value != null && value != false) productIds.add(key.toString());
          });
        }

        final shopsMap = data['shops'];
        if (shopsMap is Map) {
          shopsMap.forEach((key, value) {
            if (value == true) shopIds.add(key.toString());
          });
        }
      }

      state = AsyncValue.data(FavoritesState(productIds: productIds, shopIds: shopIds));

      // Process any pending offline sync operations asynchronously
      _syncPendingQueue();

      // Set up a listener for real-time updates from other devices
      _favoritesSubscription = _rtdb.ref('users/$userId/favorites').onValue.listen((event) {
        if (event.snapshot.value is! Map) {
           state = AsyncValue.data(FavoritesState(productIds: {}, shopIds: {}));
           return;
        }

        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final newProductIds = <String>{};
        final newShopIds = <String>{};

        final products = data['products'];
        if (products is Map) {
          products.forEach((key, value) {
            if (value != null && value != false) newProductIds.add(key.toString());
          });
        }
        final shops = data['shops'];
        if (shops is Map) {
          shops.forEach((key, value) {
            if (value == true) newShopIds.add(key.toString());
          });
        }

        state = AsyncValue.data(FavoritesState(productIds: newProductIds, shopIds: newShopIds));
      }, onError: (Object e, StackTrace st) {
        // Surface listener failures (e.g. permission revoked) instead of leaving
        // the previous state silently stale.
        state = AsyncValue.error(e, st);
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

  Future<void> toggleFavoriteProduct(String productId, {String? shopId}) async {
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
    // Store shopId as the value (instead of `true`) so we can do O(1) lookups later.
    final dbPath = 'users/$userId/favorites/products/$productId';
    try {
      if (isFavorite) {
        await _rtdb.ref(dbPath).remove().timeout(const Duration(seconds: 3));
      } else {
        await _rtdb.ref(dbPath).set(shopId ?? true).timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      // 3. Fallback: Save to offline sync queue if network write fails/times out
      _syncQueue.add({
        'type': 'product',
        'id': productId,
        'shopId': shopId,
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

  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return [];

  final rtdb = FirebaseDatabase.instance.ref();
  final List<Product> products = [];

  // Each favorited product entry stores shopId as its value (or `true` for legacy entries).
  // Read the full products map once to get shopId-keyed values.
  final favSnapshot = await rtdb.child('users/$userId/favorites/products').get();
  final Map<String, String> productShopMap = {};
  if (favSnapshot.exists && favSnapshot.value != null) {
    final raw = favSnapshot.value as Map<dynamic, dynamic>;
    raw.forEach((k, v) {
      // v is shopId string (new) or true (legacy — shopId unknown)
      if (v is String && v.isNotEmpty) {
        productShopMap[k.toString()] = v;
      }
    });
  }

  // Fetch only the specific products we need, using their known shopIds
  final futures = favoritesState.productIds.map((productId) async {
    final shopId = productShopMap[productId];
    if (shopId == null) return; // legacy entry with no shopId — skip
    final snap = await rtdb.child('products/$shopId/$productId').get();
    if (snap.exists && snap.value is Map) {
      try {
        products.add(Product.fromRTDB(
          productId,
          shopId,
          Map<dynamic, dynamic>.from(snap.value as Map),
        ));
      } catch (_) {}
    }
  });
  await Future.wait(futures);
  return products;
});

final favoriteShopsProvider = FutureProvider<List<Shop>>((ref) async {
  final favoritesStateAsync = ref.watch(favoritesProvider);
  final favoritesState = favoritesStateAsync.value;
  if (favoritesState == null || favoritesState.shopIds.isEmpty) return [];

  final rtdb = FirebaseDatabase.instance.ref();
  
  final futures = favoritesState.shopIds.map((shopId) async {
    try {
      final snapshot = await rtdb.child('shop/$shopId').get();
      if (snapshot.value is Map) {
        return Shop.fromRTDB(
          shopId,
          Map<dynamic, dynamic>.from(snapshot.value as Map),
        );
      }
    } catch (e) {
      debugPrint('Error fetching/parsing favorite shop $shopId: $e');
    }
    return null;
  });

  final results = await Future.wait(futures);
  return results.whereType<Shop>().toList();
});
