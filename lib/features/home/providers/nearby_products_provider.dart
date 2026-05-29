import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/product.dart';

final nearbyProductsProvider = StreamProvider.autoDispose<List<Product>>((ref) async* {
  final shops = ref.watch(nearbyShopsProvider).value ?? [];

  if (shops.isEmpty) {
    yield <Product>[];
    return;
  }

  final shopIds = shops.map((s) => s.id).toSet();

  // See nearbyShopsProvider: keep cache on screen if a later fetch fails, but
  // surface the error if nothing has been emitted yet.
  var hasYielded = false;

  // 1. Serve cache immediately
  try {
    final cached = await DataCacheService.getCachedProducts();
    if (cached.isNotEmpty) {
      final valid = cached.where((p) => shopIds.contains(p.shopId)).toList();
      if (valid.isNotEmpty) {
        yield valid;
        hasYielded = true;
      }
    }
  } catch (e) {
    debugPrint('Error yielding cached products: $e');
  }

  // 2. Single parallel .get() per shop — no persistent per-shop connections.
  //    Capped at 15 shops; products per shop fetched only once per refresh cycle.
  try {
    final targetShopIds = shopIds.take(15).toList();
    final snapshots = await Future.wait(
      targetShopIds.map((id) => FirebaseDatabase.instance.ref('products/$id').get()),
    );

    final List<Product> allProducts = [];
    for (int i = 0; i < snapshots.length; i++) {
      final shopId = targetShopIds[i];
      final snapshot = snapshots[i];
      if (!snapshot.exists || snapshot.value == null) continue;

      final productsMap = snapshot.value as Map<dynamic, dynamic>;
      productsMap.forEach((productIdKey, productValue) {
        if (productValue is Map) {
          try {
            final product = Product.fromRTDB(
              productIdKey.toString(),
              shopId,
              Map<dynamic, dynamic>.from(productValue),
            );
            if (product.isActive && !product.isOutOfStock) allProducts.add(product);
          } catch (e) {
            debugPrint('Error parsing product: $e');
          }
        }
      });
    }

    await DataCacheService.cacheProducts(allProducts);
    yield allProducts;
    hasYielded = true;
  } catch (e) {
    debugPrint('Error fetching products: $e');
    if (!hasYielded) rethrow;
  }
});
