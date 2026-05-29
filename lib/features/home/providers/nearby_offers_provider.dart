import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';

final nearbyOffersProvider = StreamProvider<List<Offer>>((ref) async* {
  final shops = ref.watch(nearbyShopsProvider).value ?? [];

  if (shops.isEmpty) {
    yield <Offer>[];
    return;
  }

  final shopIds = shops.map((s) => s.id).toSet();
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

  final now = DateTime.now();

  // 2. Fetch only nearby shops' offers in parallel — no full-tree download.
  //    Capped at 20 shops to bound the parallel request count.
  try {
    final targetShopIds = shopIds.take(20).toList();
    final snapshots = await Future.wait(
      targetShopIds.map((id) => FirebaseDatabase.instance.ref('offers/$id').get()),
    );

    final List<Offer> offers = [];
    for (int i = 0; i < snapshots.length; i++) {
      final shopId = targetShopIds[i];
      final snapshot = snapshots[i];
      if (!snapshot.exists || snapshot.value == null) continue;

      final offersMap = snapshot.value as Map<dynamic, dynamic>;
      offersMap.forEach((offerIdKey, offerValue) {
        if (offerValue is Map) {
          try {
            final offer = Offer.fromRTDB(
              offerIdKey.toString(),
              shopId,
              Map<dynamic, dynamic>.from(offerValue),
            ).copyWith(shopName: shopNames[shopId] ?? '');

            final active = (offer.endDate == null || offer.endDate!.isAfter(now)) &&
                (offer.startDate == null || offer.startDate!.isBefore(now));
            if (offer.isActive && active) offers.add(offer);
          } catch (e) {
            debugPrint('Error parsing offer: $e');
          }
        }
      });
    }

    offers.sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
    await DataCacheService.cacheOffers(offers);
    yield offers;
    hasYielded = true;
  } catch (e) {
    debugPrint('Error fetching offers: $e');
    if (!hasYielded) rethrow;
  }
});
