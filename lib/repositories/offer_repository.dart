import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
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
  final FirebaseFunctions _functions;

  FirebaseOfferRepository({
    FirebaseDatabase? database,
    FirebaseFunctions? functions,
  })  : _database = database ?? FirebaseDatabase.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

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
    if (shopIds.isEmpty) return <Offer>[];

    final targetShopIds = shopIds.take(20).toList();
    final List<Offer> offers = [];

    try {
      final callable = _functions.httpsCallable('getNearbyOffersAggregated');
      final response = await callable.call({
        'shopIds': targetShopIds,
      });

      final data = response.data;
      if (data is Map && data['offers'] is List) {
        for (final item in data['offers']) {
          if (item is Map) {
            try {
              final id = item['id']?.toString() ?? '';
              final shopId = item['shopId']?.toString() ?? '';
              final offer = Offer.fromRTDB(
                id,
                shopId,
                Map<dynamic, dynamic>.from(item),
              );
              offers.add(offer);
            } catch (e) {
              debugPrint('Error parsing offer from aggregated response: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching nearby offers through aggregation function: $e');
      return <Offer>[];
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
