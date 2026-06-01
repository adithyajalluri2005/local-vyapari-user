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

    final geoDocs = await geoRef.fetchWithin(
      center: GeoFirePoint(GeoPoint(sortingLat, sortingLng)),
      radiusInKm: 15,
      field: 'geo',
      geopointFrom: (data) =>
          (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
      strictMode: true,
    );

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

    ref.onDispose(() {
      for (final sub in subscriptions) { sub.cancel(); }
      if (!controller.isClosed) controller.close();
    });

    // Stream and yield live shop lists as RTDB pushes changes
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
  } catch (e) {
    debugPrint('Error in nearbyShopsProvider: $e');
    if (!hasYielded) rethrow;
  }
});
