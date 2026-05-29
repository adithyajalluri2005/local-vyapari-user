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
  Future.microtask(() => ref.read(lastQueryCenterProvider.notifier).setCenter(newCenter));
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

  // Tracks whether the UI has already received data. If it has, a later fetch
  // failure leaves the cached data on screen (stale-while-revalidate); if it
  // hasn't, the failure is rethrown so the UI shows an error instead of an
  // endless loading state.
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

  // 2. Geo-bounded query against the Cloud-Function-maintained Firestore index
  //    (searchable_shops, populated by onShopProfileUpdate with a geopoint).
  //    Only shops within the radius are returned, so transferred data scales with
  //    nearby shops — not with the total number of shops in the system.
  //    Shops without valid coordinates are never indexed, so unconfigured shops
  //    can never surface here.
  //    Provider re-runs automatically when queryCenterProvider changes (user moves
  //    >300 m) or when ref.invalidate(nearbyShopsProvider) is called (pull-to-refresh).
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

    // Fetch the full shop records for just the nearby IDs (bounded fan-out).
    final shopSnaps = await Future.wait(
      shopIds.map((id) => FirebaseDatabase.instance.ref('shop/$id').get()),
    );

    final List<({Shop shop, double dist})> withDist = [];
    for (int i = 0; i < shopSnaps.length; i++) {
      final snap = shopSnaps[i];
      if (!snap.exists || snap.value == null) continue;
      try {
        final shop = Shop.fromRTDB(
          shopIds[i],
          Map<dynamic, dynamic>.from(snap.value as Map),
        );
        final d = Geolocator.distanceBetween(
          sortingLat, sortingLng,
          shop.location.latitude, shop.location.longitude,
        );
        if (d <= 15000.0) withDist.add((shop: shop, dist: d));
      } catch (e) {
        debugPrint('Error parsing shop: $e');
      }
    }

    withDist.sort((a, b) => a.dist.compareTo(b.dist));
    final sortedShops = withDist.map((e) => e.shop).toList();

    await DataCacheService.cacheShops(sortedShops);
    await DataCacheService.cacheLastLocation(sortingLat, sortingLng);
    yield sortedShops;
    hasYielded = true;
  } catch (e) {
    debugPrint('Error fetching shops: $e');
    // Nothing on screen yet → surface the error instead of hanging on loading.
    if (!hasYielded) rethrow;
  }
});
