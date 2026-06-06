import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/repositories/product_repository.dart';

final nearbyProductsProvider = StreamProvider.autoDispose<List<Product>>((ref) async* {
  final shopIdsString = ref.watch(nearbyShopsProvider.select(
    (val) => val.value?.map((s) => s.id).join(',') ?? '',
  ));

  if (shopIdsString.isEmpty) {
    yield <Product>[];
    return;
  }

  final shopIds = shopIdsString.split(',').toSet();

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

  // 2. Fetch from repository
  try {
    final targetShopIds = shopIds.take(15).toList();
    final repo = ref.read(productRepositoryProvider);
    final allProducts = await repo.getNearbyProducts(targetShopIds);

    await DataCacheService.cacheProducts(allProducts);
    yield allProducts;
    hasYielded = true;
  } catch (e) {
    debugPrint('Error fetching products: $e');
    if (!hasYielded) rethrow;
  }
});
