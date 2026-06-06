import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

abstract class ShopRepository {
  Stream<List<Shop>> getNearbyShops({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  });

  Future<Shop?> getShopDetails(String shopId);

  Stream<Shop?> streamShopDetails(String shopId);
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) => FirebaseShopRepository());

class FirebaseShopRepository implements ShopRepository {
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;

  FirebaseShopRepository({
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _database = database ?? FirebaseDatabase.instance;

  @override
  Stream<List<Shop>> getNearbyShops({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) async* {
    final geoRef = GeoCollectionReference<Map<String, dynamic>>(
      _firestore.collection('searchable_shops'),
    );
    final center = GeoFirePoint(GeoPoint(latitude, longitude));

    GeoPoint geopointFrom(Map<String, dynamic> data) {
      try {
        final geo = data['geo'];
        if (geo is Map) {
          final geopoint = geo['geopoint'];
          if (geopoint is GeoPoint) return geopoint;
        }
      } catch (_) {}
      return const GeoPoint(0, 0);
    }

    Stream<List<Shop>> buildStream() => geoRef
        .subscribeWithin(
          center: center,
          radiusInKm: radiusInKm,
          field: 'geo',
          geopointFrom: geopointFrom,
          strictMode: true,
        )
        .map((docs) {
          final shops = <Shop>[];
          for (final doc in docs) {
            if (doc.data() == null) continue;
            try {
              shops.add(Shop.fromFirestore(doc));
            } catch (e) {
              debugPrint('Error parsing shop ${doc.id}: $e');
            }
          }
          shops.sort((a, b) {
            final dA = Geolocator.distanceBetween(
              latitude, longitude,
              a.location.latitude, a.location.longitude,
            );
            final dB = Geolocator.distanceBetween(
              latitude, longitude,
              b.location.latitude, b.location.longitude,
            );
            return dA.compareTo(dB);
          });
          return shops;
        });

    // App Check token may not be ready at startup; retry once on permission-denied.
    try {
      yield* buildStream();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await Future.delayed(const Duration(seconds: 2));
        yield* buildStream();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<Shop?> getShopDetails(String shopId) async {
    final event = await _database.ref('shop/$shopId').once();
    final snapshot = event.snapshot;
    if (snapshot.value is! Map) return null;
    try {
      final shopData = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return Shop.fromRTDB(shopId, shopData);
    } catch (e) {
      debugPrint('Error parsing shop $shopId: $e');
      return null;
    }
  }

  @override
  Stream<Shop?> streamShopDetails(String shopId) {
    return _database.ref('shop/$shopId').onValue.map((event) {
      final snapshot = event.snapshot;
      if (snapshot.value is! Map) return null;
      final shopData = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return Shop.fromRTDB(shopId, shopData);
    });
  }
}
