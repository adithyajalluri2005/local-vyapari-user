import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';

abstract class OfferRepository {
  Future<List<Offer>> getShopOffers(String shopId);
  Future<List<Offer>> getNearbyOffers(List<String> shopIds);
  Future<Offer?> getOfferDetails(String shopId, String offerId);
  Stream<Offer?> streamOfferDetails(String shopId, String offerId);
}

final offerRepositoryProvider = Provider<OfferRepository>((ref) => FirebaseOfferRepository());

class FirebaseOfferRepository implements OfferRepository {
  final FirebaseDatabase _database;

  FirebaseOfferRepository({
    FirebaseDatabase? database,
  })  : _database = database ?? FirebaseDatabase.instance;

  @override
  Future<List<Offer>> getShopOffers(String shopId) async {
    final snapshot = await _database.ref('offers/$shopId').get();
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
  }

  @override
  Future<List<Offer>> getNearbyOffers(List<String> shopIds) async {
    final targetShopIds = shopIds.take(20).toList();
    final snapshots = await Future.wait(
      targetShopIds.map((id) => _database.ref('offers/$id').get()),
    );

    final now = DateTime.now();
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
            );

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
    return offers;
  }

  @override
  Future<Offer?> getOfferDetails(String shopId, String offerId) async {
    final event = await _database.ref('offers/$shopId/$offerId').once();
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value is! Map) return null;
    final offerData = Map<dynamic, dynamic>.from(snapshot.value as Map);
    return Offer.fromRTDB(offerId, shopId, offerData);
  }

  @override
  Stream<Offer?> streamOfferDetails(String shopId, String offerId) {
    return _database
        .ref('offers/$shopId/$offerId')
        .onValue
        .map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value is! Map) return null;
      final offerData = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return Offer.fromRTDB(offerId, shopId, offerData);
    });
  }
}
