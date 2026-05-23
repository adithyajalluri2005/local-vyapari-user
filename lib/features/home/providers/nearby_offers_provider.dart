import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';

final nearbyOffersProvider = StreamProvider<List<Offer>>((ref) async* {
  // 1. Watch shops changes first
  final shopsAsyncValue = ref.watch(nearbyShopsProvider);
  final shops = shopsAsyncValue.value ?? [];

  if (shops.isEmpty) {
    yield <Offer>[];
    return;
  }

  final shopIds = shops.map((s) => s.id).toSet();
  final shopNames = {for (var s in shops) s.id: s.shopName};

  // 2. Yield local cached offers immediately if they belong to current nearby shops
  try {
    final cached = await DataCacheService.getCachedOffers();
    if (cached.isNotEmpty) {
      final validCached = cached
          .where((o) => shopIds.contains(o.shopId))
          .map((o) => o.copyWith(shopName: shopNames[o.shopId] ?? ''))
          .toList();
      if (validCached.isNotEmpty) {
        yield validCached;
      }
    }
  } catch (e) {
    debugPrint('Error yielding cached offers: $e');
  }

  final now = DateTime.now();
  final dbRef = FirebaseDatabase.instance.ref('offers');

  // 3. Yield remote database values reactively
  await for (final event in dbRef.onValue) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) {
      yield <Offer>[];
      continue;
    }

    final Map<dynamic, dynamic> shopsOffersMap = snapshot.value as Map<dynamic, dynamic>;
    final List<Offer> offers = [];

    shopsOffersMap.forEach((shopIdKey, offersValue) {
      final shopId = shopIdKey.toString();
      if (shopIds.contains(shopId) && offersValue is Map) {
        offersValue.forEach((offerIdKey, offerValue) {
          if (offerValue is Map) {
            try {
              final offerId = offerIdKey.toString();
              final offerData = Map<dynamic, dynamic>.from(offerValue);
              final offer = Offer.fromRTDB(offerId, shopId, offerData).copyWith(
                shopName: shopNames[shopId] ?? '',
              );
              final isTimeActive = (offer.endDate == null || offer.endDate!.isAfter(now)) &&
                  (offer.startDate == null || offer.startDate!.isBefore(now));
              if (offer.isActive && isTimeActive) {
                offers.add(offer);
              }
            } catch (e) {
              debugPrint('Error parsing offer $offerIdKey: $e');
            }
          }
        });
      }
    });

    offers.sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));

    // 4. Save to local cache
    await DataCacheService.cacheOffers(offers);

    yield offers;
  }
});
