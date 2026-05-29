import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/product.dart';

final nearbyProductsProvider = StreamProvider.autoDispose<List<Product>>((ref) async* {
  Timer? cacheDebounce;
  ref.onDispose(() => cacheDebounce?.cancel());

  // 1. Watch shops changes first
  final shopsAsyncValue = ref.watch(nearbyShopsProvider);
  final shops = shopsAsyncValue.value ?? [];

  if (shops.isEmpty) {
    yield <Product>[];
    return;
  }

  // 2. Yield local cached products immediately if they belong to current nearby shops
  try {
    final cached = await DataCacheService.getCachedProducts();
    if (cached.isNotEmpty) {
      final shopIds = shops.map((s) => s.id).toSet();
      final validCached = cached.where((p) => shopIds.contains(p.shopId)).toList();
      if (validCached.isNotEmpty) {
        yield validCached;
      }
    }
  } catch (e) {
    debugPrint('Error yielding cached products: $e');
  }

  final shopIds = shops.map((s) => s.id).toSet();

  if (shopIds.isEmpty) {
    yield <Product>[];
    return;
  }

  // Create one stream per nearby shop
  final streams = shopIds.map((shopId) =>
    FirebaseDatabase.instance.ref('products/$shopId').onValue
      .map((event) => (shopId, event))
  ).toList();

  final merged = StreamGroup.merge(streams);

  // Maintain a mutable map of products per shop so each stream event
  // only updates its own shop's products
  final Map<String, List<Product>> productsByShop = {};

  await for (final (shopId, event) in merged) {
    final snapshot = event.snapshot;
    final List<Product> shopProducts = [];

    if (snapshot.exists && snapshot.value != null) {
      final productsMap = snapshot.value as Map<dynamic, dynamic>;
      productsMap.forEach((productIdKey, productValue) {
        if (productValue is Map) {
          try {
            final product = Product.fromRTDB(
              productIdKey.toString(), shopId,
              Map<dynamic, dynamic>.from(productValue));
            if (product.isActive && !product.isOutOfStock) {
              shopProducts.add(product);
            }
          } catch (e) {
            debugPrint('Error parsing product $productIdKey: $e');
          }
        }
      });
    }
    productsByShop[shopId] = shopProducts;

    final allProducts = productsByShop.values.expand((p) => p).toList();
    // Debounce cache writes so rapid multi-shop events don't thrash disk
    cacheDebounce?.cancel();
    cacheDebounce = Timer(const Duration(seconds: 2), () {
      DataCacheService.cacheProducts(allProducts);
    });
    yield allProducts;
  }
});
