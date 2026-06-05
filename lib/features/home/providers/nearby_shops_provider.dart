import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

class LastQueryCenterNotifier extends Notifier<GeoPoint?> {
  @override
  GeoPoint? build() => null;
  void setCenter(GeoPoint? center) => state = center;
}

final lastQueryCenterProvider =
    NotifierProvider<LastQueryCenterNotifier, GeoPoint?>(LastQueryCenterNotifier.new);

// Only triggers a new fetch when the user moves >300 m — keeps rebuilds minimal.
final queryCenterProvider = Provider<GeoPoint?>((ref) {
  final loc = ref.watch(activeBrowsingLocationProvider).value;
  if (loc == null) return null;

  final lastCenter = ref.read(lastQueryCenterProvider);
  if (lastCenter != null) {
    final dist = Geolocator.distanceBetween(
      loc.latitude, loc.longitude,
      lastCenter.latitude, lastCenter.longitude,
    );
    if (dist <= 300) return lastCenter;
  }

  final newCenter = GeoPoint(loc.latitude, loc.longitude);
  Future.microtask(
      () => ref.read(lastQueryCenterProvider.notifier).setCenter(newCenter));
  return newCenter;
});

final nearbyShopsProvider = StreamProvider<List<Shop>>((ref) async* {
  final centerPoint = ref.watch(queryCenterProvider);
  if (centerPoint == null) {
    yield <Shop>[];
    return;
  }

  final userLocation = ref.read(activeBrowsingLocationProvider).value;
  final sortingLat = userLocation?.latitude ?? centerPoint.latitude;
  final sortingLng = userLocation?.longitude ?? centerPoint.longitude;

  var hasYielded = false;

  // 1. Serve cache immediately (stale-while-revalidate)
  try {
    final cached = await DataCacheService.getCachedShops();
    final cachedLoc = await DataCacheService.getCachedLastLocation();
    if (cached.isNotEmpty && cachedLoc != null) {
      final dist = Geolocator.distanceBetween(
        sortingLat, sortingLng,
        cachedLoc['latitude']!, cachedLoc['longitude']!,
      );
      if (dist <= 15000) {
        yield cached;
        hasYielded = true;
      }
    }
  } catch (e) {
    debugPrint('Error yielding cached shops: $e');
  }

  // 2. Geo-bounded Firestore query for nearby shop IDs (index only — one-time)
  try {
    final geoRef = GeoCollectionReference<Map<String, dynamic>>(
      FirebaseFirestore.instance.collection('searchable_shops'),
    );

    // App Check token may not be ready on the first attempt (race at startup);
    // one retry after a short delay resolves the transient permission-denied.
    Future<List<DocumentSnapshot<Map<String, dynamic>>>> fetchWithRetry() async {
      try {
        return await geoRef.fetchWithin(
          center: GeoFirePoint(GeoPoint(sortingLat, sortingLng)),
          radiusInKm: 15,
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
            center: GeoFirePoint(GeoPoint(sortingLat, sortingLng)),
            radiusInKm: 15,
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

    final geoDocs = await fetchWithRetry();

    final shopIds = geoDocs.map((doc) => doc.id).toList();
    if (shopIds.isEmpty) {
      yield <Shop>[];
      return;
    }

    // 3. Real-time RTDB listeners for each shop.
    //    Any field change (including isOpen toggle) emits immediately.
    final Map<String, Shop> shopMap = {};
    final controller = StreamController<List<Shop>>();
    final subscriptions = <StreamSubscription>[];

    List<Shop> buildSorted() {
      final list = shopMap.values.toList();
      list.sort((a, b) {
        final dA = Geolocator.distanceBetween(
          sortingLat, sortingLng,
          a.location.latitude, a.location.longitude,
        );
        final dB = Geolocator.distanceBetween(
          sortingLat, sortingLng,
          b.location.latitude, b.location.longitude,
        );
        return dA.compareTo(dB);
      });
      return list;
    }

    for (final id in shopIds) {
      final sub = FirebaseDatabase.instance
          .ref('shop/$id')
          .onValue
          .listen(
        (event) {
          if (event.snapshot.exists && event.snapshot.value != null) {
            try {
              final shop = Shop.fromRTDB(
                id,
                Map<dynamic, dynamic>.from(event.snapshot.value as Map),
              );
              final d = Geolocator.distanceBetween(
                sortingLat, sortingLng,
                shop.location.latitude, shop.location.longitude,
              );
              if (d <= 15000.0) {
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

    void cleanup() {
      for (final sub in subscriptions) { sub.cancel(); }
      if (!controller.isClosed) controller.close();
    }

    // Guard: if the provider was disposed while fetchWithRetry awaited,
    // clean up immediately and stop — calling ref.onDispose after disposal throws.
    if (!ref.mounted) { cleanup(); return; }
    ref.onDispose(cleanup);

    // Force an emission after 10 s if RTDB hasn't responded yet, so the UI
    // shows an empty state instead of loading indefinitely.
    Future.delayed(const Duration(seconds: 10), () {
      if (!controller.isClosed && !hasYielded) {
        controller.add(buildSorted());
      }
    });

    // Stream and yield live shop lists as RTDB pushes changes.
    var firstEmission = true;
    await for (final shops in controller.stream) {
      if (firstEmission) {
        firstEmission = false;
        try {
          await DataCacheService.cacheShops(shops);
          await DataCacheService.cacheLastLocation(sortingLat, sortingLng);
        } catch (_) {}
      }
      yield shops;
      hasYielded = true;
    }
  } catch (e, st) {
    debugPrint('Error in nearbyShopsProvider [${e.runtimeType}]: $e\n$st');
    if (!hasYielded) rethrow;
  }
});
