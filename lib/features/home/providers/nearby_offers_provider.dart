import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';

final nearbyOffersProvider = StreamProvider<List<Offer>>((ref) {
  final shopsAsyncValue = ref.watch(nearbyShopsProvider);
  final shops = shopsAsyncValue.value ?? [];

  if (shops.isEmpty) {
    return Stream.value(<Offer>[]);
  }

  final shopIds = shops.map((s) => s.id).toSet();
  final now = DateTime.now();
  final dbRef = FirebaseDatabase.instance.ref('offers');

  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) {
      return <Offer>[];
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
              final offer = Offer.fromRTDB(offerId, shopId, offerData);
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
    return offers;
  }).handleError((error) {
    debugPrint('Error in nearbyOffersProvider stream: $error');
    return <Offer>[];
  });
});
