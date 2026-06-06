import 'dart:async';
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

    Future<List<DocumentSnapshot<Map<String, dynamic>>>> fetchWithRetry() async {
      try {
        return await geoRef.fetchWithin(
          center: GeoFirePoint(GeoPoint(latitude, longitude)),
          radiusInKm: radiusInKm,
          field: 'geo',
          geopointFrom: (data) {
            try {
              final geo = data['geo'];
              if (geo is Map) {
                final geopoint = geo['geopoint'];
                if (geopoint is GeoPoint) return geopoint;
              }
            } catch (_) {}
            return const GeoPoint(0, 0);
          },
          strictMode: true,
        );
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          await Future.delayed(const Duration(seconds: 2));
          return geoRef.fetchWithin(
            center: GeoFirePoint(GeoPoint(latitude, longitude)),
            radiusInKm: radiusInKm,
            field: 'geo',
            geopointFrom: (data) {
              try {
                final geo = data['geo'];
                if (geo is Map) {
                  final geopoint = geo['geopoint'];
                  if (geopoint is GeoPoint) return geopoint;
                }
              } catch (_) {}
              return const GeoPoint(0, 0);
            },
            strictMode: true,
          );
        }
        rethrow;
      }
    }

    List<DocumentSnapshot<Map<String, dynamic>>> geoDocs;
    try {
      geoDocs = await fetchWithRetry();
    } catch (e) {
      debugPrint('Failed to fetch nearby shop geoDocs: $e');
      yield <Shop>[];
      return;
    }

    final shopIds = geoDocs.map((doc) => doc.id).toList();
    if (shopIds.isEmpty) {
      yield <Shop>[];
      return;
    }

    final Map<String, Shop> shopMap = {};
    final controller = StreamController<List<Shop>>();
    final subscriptions = <StreamSubscription>[];

    List<Shop> buildSorted() {
      final list = shopMap.values.toList();
      list.sort((a, b) {
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
      return list;
    }

    for (final id in shopIds) {
      final sub = _database.ref('shop/$id').onValue.listen(
        (event) {
          if (event.snapshot.exists && event.snapshot.value != null) {
            try {
              final shop = Shop.fromRTDB(
                id,
                Map<dynamic, dynamic>.from(event.snapshot.value as Map),
              );
              final d = Geolocator.distanceBetween(
                latitude, longitude,
                shop.location.latitude, shop.location.longitude,
              );
              if (d <= radiusInKm * 1000.0) {
                shopMap[id] = shop;
              } else {
                shopMap.remove(id);
              }
            } catch (e) {
              debugPrint('Error parsing shop $id: $e');
            }
          } else {
            shopMap.remove(id);
          }

          if (!controller.isClosed) {
            controller.add(buildSorted());
          }
        },
        onError: (e) => debugPrint('RTDB stream error for $id: $e'),
      );
      subscriptions.add(sub);
    }

    // Force an emission after 10 s if RTDB hasn't responded yet, so the UI
    // shows an empty/cached state instead of loading indefinitely.
    final timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!controller.isClosed) {
        controller.add(buildSorted());
      }
    });

    controller.onCancel = () {
      timeoutTimer.cancel();
      for (final sub in subscriptions) {
        sub.cancel();
      }
      controller.close();
    };

    yield* controller.stream;
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
