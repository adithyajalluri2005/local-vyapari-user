import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/product.dart';

final nearbyProductsProvider = StreamProvider<List<Product>>((ref) async* {
  // 1. Yield local cached products immediately for instant UI response
  try {
    final cached = await DataCacheService.getCachedProducts();
    if (cached.isNotEmpty) {
      yield cached;
    }
  } catch (e) {
    debugPrint('Error yielding cached products: $e');
  }

  // 2. Watch shops changes
  final shopsAsyncValue = ref.watch(nearbyShopsProvider);
  final shops = shopsAsyncValue.value ?? [];

  if (shops.isEmpty) {
    return;
  }

  final shopIds = shops.map((s) => s.id).toSet();
  final dbRef = FirebaseDatabase.instance.ref('products');

  // 3. Yield remote database values reactively
  await for (final event in dbRef.onValue) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) {
      yield <Product>[];
      continue;
    }

    final Map<dynamic, dynamic> shopsProductsMap = snapshot.value as Map<dynamic, dynamic>;
    final List<Product> products = [];

    shopsProductsMap.forEach((shopIdKey, productsValue) {
      final shopId = shopIdKey.toString();
      if (shopIds.contains(shopId) && productsValue is Map) {
        productsValue.forEach((productIdKey, productValue) {
          if (productValue is Map) {
            try {
              final productId = productIdKey.toString();
              final productData = Map<dynamic, dynamic>.from(productValue);
              final product = Product.fromRTDB(productId, shopId, productData);
              if (product.isActive && !product.isOutOfStock) {
                products.add(product);
              }
            } catch (e) {
              debugPrint('Error parsing product $productIdKey: $e');
            }
          }
        });
      }
    });

    // 4. Save to local cache
    await DataCacheService.cacheProducts(products);

    yield products;
  }
});
