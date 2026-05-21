import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

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

  Future<void> toggleFavoriteProduct(String productId) async {
    final userId = _userId;
    if (userId == null) return; // Ignore if not logged in

    final currentState = state.value;
    if (currentState == null) return;

    final isFavorite = currentState.productIds.contains(productId);
    final ref = _rtdb.ref('users/$userId/favorites/products/$productId');

    if (isFavorite) {
      await ref.remove();
    } else {
      await ref.set(true);
    }
  }

  Future<void> toggleFavoriteShop(String shopId) async {
    final userId = _userId;
    if (userId == null) return; // Ignore if not logged in

    final currentState = state.value;
    if (currentState == null) return;

    final isFavorite = currentState.shopIds.contains(shopId);
    final ref = _rtdb.ref('users/$userId/favorites/shops/$shopId');

    if (isFavorite) {
      await ref.remove();
    } else {
      await ref.set(true);
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
