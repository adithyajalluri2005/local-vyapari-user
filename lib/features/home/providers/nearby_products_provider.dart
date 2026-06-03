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

    // Collect raw products per shop into buckets.
    final Map<String, List<Product>> byShop = {};
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
            if (product.isActive && !product.isOutOfStock) {
              byShop.putIfAbsent(shopId, () => []).add(product);
            }
          } catch (e) {
            debugPrint('Error parsing product: $e');
          }
        }
      });
    }

    // Per-shop: sort by highest discount first, then cap at 6.
    // This prevents a single shop with 100 products from flooding the feed.
    const kMaxPerShop = 6;
    final shopBuckets = byShop.values.map((products) {
      products.sort((a, b) {
        final dA = a.actualPrice > 0 ? (a.actualPrice - a.offerPrice) / a.actualPrice : 0.0;
        final dB = b.actualPrice > 0 ? (b.actualPrice - b.offerPrice) / b.actualPrice : 0.0;
        return dB.compareTo(dA);
      });
      return products.take(kMaxPerShop).toList();
    }).toList();

    // Interleave round-robin across shops so variety appears immediately.
    // e.g. shop A → shop B → shop C → shop A → shop B → ...
    final List<Product> allProducts = [];
    final maxLen = shopBuckets.fold(0, (m, b) => b.length > m ? b.length : m);
    for (int i = 0; i < maxLen; i++) {
      for (final bucket in shopBuckets) {
        if (i < bucket.length) allProducts.add(bucket[i]);
      }
    }

    await DataCacheService.cacheProducts(allProducts);
    yield allProducts;
    hasYielded = true;
  } catch (e) {
    debugPrint('Error fetching products: $e');
    if (!hasYielded) rethrow;
  }
});
