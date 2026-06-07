import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Lightweight geo-query that emits only the list of shop IDs within radius.
  /// Use this with [streamShopsByIds] to separate "which shops are nearby"
  /// from "what is the current data for those shops".
  Stream<List<String>> streamNearbyShopIds({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  });

  /// Real-time Firestore stream for a given set of shop IDs.
  /// Emits whenever any shop document in the set is updated (isOpen, rating, etc.)
  /// without touching the geo-query.
  Stream<List<Shop>> streamShopsByIds(List<String> shopIds);

  Future<Shop?> getShopDetails(String shopId);

  Stream<Shop?> streamShopDetails(String shopId);
}

final shopRepositoryProvider = Provider<ShopRepository>((ref) => FirebaseShopRepository());

class FirebaseShopRepository implements ShopRepository {
  final FirebaseFirestore _firestore;

  FirebaseShopRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Shared geo helpers ───────────────────────────────────────────────────

  GeoCollectionReference<Map<String, dynamic>> get _geoRef =>
      GeoCollectionReference<Map<String, dynamic>>(
        _firestore.collection('searchable_shops'),
      );

  static GeoPoint _geopointFrom(Map<String, dynamic> data) {
    try {
      final geo = data['geo'];
      if (geo is Map) {
        final geopoint = geo['geopoint'];
        if (geopoint is GeoPoint) return geopoint;
      }
    } catch (_) {}
    return const GeoPoint(0, 0);
  }

  // ── getNearbyShops ───────────────────────────────────────────────────────

  @override
  Stream<List<Shop>> getNearbyShops({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) async* {
    final center = GeoFirePoint(GeoPoint(latitude, longitude));

    Stream<List<Shop>> build() => _geoRef
        .subscribeWithin(
          center: center,
          radiusInKm: radiusInKm,
          field: 'geo',
          geopointFrom: _geopointFrom,
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

    try {
      yield* build();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await Future.delayed(const Duration(seconds: 2));
        yield* build();
      } else {
        rethrow;
      }
    }
  }

  // ── streamNearbyShopIds ──────────────────────────────────────────────────

  @override
  Stream<List<String>> streamNearbyShopIds({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) async* {
    final center = GeoFirePoint(GeoPoint(latitude, longitude));

    Stream<List<String>> build() => _geoRef
        .subscribeWithin(
          center: center,
          radiusInKm: radiusInKm,
          field: 'geo',
          geopointFrom: _geopointFrom,
          strictMode: true,
        )
        .map((docs) => docs.map((d) => d.id).toList());

    try {
      yield* build();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await Future.delayed(const Duration(seconds: 2));
        yield* build();
      } else {
        rethrow;
      }
    }
  }

  // ── streamShopsByIds (Firestore whereIn) ─────────────────────────────────

  @override
  Stream<List<Shop>> streamShopsByIds(List<String> shopIds) {
    if (shopIds.isEmpty) return Stream.value([]);

    // Chunk into groups of 30 (Firestore whereIn limit)
    final chunks = <List<String>>[];
    for (var i = 0; i < shopIds.length; i += 30) {
      chunks.add(shopIds.sublist(i, (i + 30).clamp(0, shopIds.length)));
    }

    Stream<List<Shop>> chunkStream(List<String> ids) => _firestore
        .collection('searchable_shops')
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots()
        .map((snap) {
          final shops = <Shop>[];
          for (final doc in snap.docs) {
            if (doc.data().isEmpty) continue;
            try {
              shops.add(Shop.fromFirestore(doc));
            } catch (e) {
              debugPrint('Error parsing shop ${doc.id}: $e');
            }
          }
          return shops;
        });

    if (chunks.length == 1) return chunkStream(chunks.first);

    return _mergeChunkStreams(chunks.map(chunkStream).toList());
  }

  /// Combines N chunk streams by keeping the latest value from each and
  /// emitting the merged list whenever any chunk updates.
  Stream<List<Shop>> _mergeChunkStreams(List<Stream<List<Shop>>> streams) {
    final controller = StreamController<List<Shop>>();
    final current = List<List<Shop>>.generate(streams.length, (_) => []);
    var done = 0;
    late final List<StreamSubscription<List<Shop>>> subs;

    subs = List.generate(streams.length, (i) {
      return streams[i].listen(
        (data) {
          current[i] = data;
          if (!controller.isClosed) {
            controller.add(current.expand((l) => l).toList());
          }
        },
        onError: (Object e, StackTrace st) {
          if (!controller.isClosed) controller.addError(e, st);
        },
        onDone: () {
          if (++done == streams.length && !controller.isClosed) {
            controller.close();
          }
        },
        cancelOnError: false,
      );
    });

    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  // ── getShopDetails & streamShopDetails (Firestore) ───────────────────────

  @override
  Future<Shop?> getShopDetails(String shopId) async {
    try {
      final doc = await _firestore.collection('searchable_shops').doc(shopId).get();
      if (!doc.exists) return null;
      return Shop.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error fetching shop $shopId: $e');
      return null;
    }
  }

  @override
  Stream<Shop?> streamShopDetails(String shopId) {
    return _firestore
        .collection('searchable_shops')
        .doc(shopId)
        .snapshots()
        .map((doc) => doc.exists ? Shop.fromFirestore(doc) : null);
  }
}
