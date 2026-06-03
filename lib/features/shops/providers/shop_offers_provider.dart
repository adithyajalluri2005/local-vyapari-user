import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';

final shopOffersProvider = FutureProvider.family<List<Offer>, String>((ref, shopId) async {
  try {
    final snapshot = await FirebaseDatabase.instance.ref('offers/$shopId').get();
    if (!snapshot.exists || snapshot.value == null) return [];

    final now = DateTime.now();
    final offersMap = snapshot.value as Map<dynamic, dynamic>;
    final offers = <Offer>[];

    offersMap.forEach((key, value) {
      if (value is Map) {
        try {
          final offer = Offer.fromRTDB(
            key.toString(),
            shopId,
            Map<dynamic, dynamic>.from(value),
          );
          final active = (offer.endDate == null || offer.endDate!.isAfter(now)) &&
              (offer.startDate == null || offer.startDate!.isBefore(now));
          if (offer.isActive && active) offers.add(offer);
        } catch (e) {
          debugPrint('Error parsing shop offer: $e');
        }
      }
    });

    offers.sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
    return offers;
  } catch (e) {
    debugPrint('Error fetching shop offers: $e');
    return [];
  }
});
