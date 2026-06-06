import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/repositories/offer_repository.dart';

final nearbyOffersProvider = StreamProvider<List<Offer>>((ref) async* {
  // Watch only the concatenated list of shop IDs. This avoids re-fetching all offers
  // if shop details change, but the set of nearby shops remains same.
  final shopIdsString = ref.watch(nearbyShopsProvider.select(
    (val) => val.value?.map((s) => s.id).join(',') ?? '',
  ));

  if (shopIdsString.isEmpty) {
    yield <Offer>[];
    return;
  }

  final shopIds = shopIdsString.split(',').toSet();
  
  // Read the latest list of shops to get shop names without subscribing to their modifications.
  final shops = ref.read(nearbyShopsProvider).value ?? [];
  final shopNames = {for (final s in shops) s.id: s.shopName};

  // See nearbyShopsProvider: keep cache on screen if a later fetch fails, but
  // surface the error if nothing has been emitted yet.
  var hasYielded = false;

  // 1. Serve cache immediately
  try {
    final cached = await DataCacheService.getCachedOffers();
    if (cached.isNotEmpty) {
      final valid = cached
          .where((o) => shopIds.contains(o.shopId))
          .map((o) => o.copyWith(shopName: shopNames[o.shopId] ?? ''))
          .toList();
      if (valid.isNotEmpty) {
        yield valid;
        hasYielded = true;
      }
    }
  } catch (e) {
    debugPrint('Error yielding cached offers: $e');
  }

  // 2. Fetch from repository
  try {
    final targetShopIds = shopIds.take(20).toList();
    final repo = ref.read(offerRepositoryProvider);
    final rawOffers = await repo.getNearbyOffers(targetShopIds);

    // Map shop names locally
    final offers = rawOffers.map((o) => o.copyWith(shopName: shopNames[o.shopId] ?? '')).toList();

    await DataCacheService.cacheOffers(offers);
    yield offers;
    hasYielded = true;
  } catch (e) {
    debugPrint('Error fetching offers: $e');
    if (!hasYielded) rethrow;
  }
});
