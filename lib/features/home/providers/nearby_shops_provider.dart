import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/repositories/shop_repository.dart';

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

// ── Smart-diff geo-query layer ───────────────────────────────────────────────
//
// Wraps the geoflutterfire_plus geo-query and emits a sorted, comma-joined
// string of shop IDs.  The key invariant: it ONLY emits when the SET of
// nearby shop IDs actually changes — NOT on every shop-data update
// (isOpen, rating, etc.) that subscribeWithin would otherwise propagate.
//
// Downstream providers (nearbyShopsProvider, notification service) watch this
// provider so they restart / re-diff only when shops enter or leave the radius,
// reducing unnecessary fetches and listener churn.
final nearbyShopIdsProvider = StreamProvider<String>((ref) async* {
  final center = ref.watch(queryCenterProvider);
  if (center == null) {
    yield '';
    return;
  }

  final userLocation = ref.read(activeBrowsingLocationProvider).value;
  final lat = userLocation?.latitude ?? center.latitude;
  final lng = userLocation?.longitude ?? center.longitude;

  final repo = ref.read(shopRepositoryProvider);
  String? lastIds;

  try {
    await for (final ids in repo.streamNearbyShopIds(
      latitude: lat,
      longitude: lng,
      radiusInKm: 15.0,
    )) {
      final sorted = (List<String>.from(ids)..sort()).join(',');
      if (sorted != lastIds) {
        lastIds = sorted;
        yield sorted;
      }
    }
  } on FirebaseException catch (e) {
    debugPrint('nearbyShopIdsProvider error [${e.code}]: $e');
    rethrow;
  }
});

// ── Real-time shop data via Firestore whereIn ────────────────────────────────
//
// Watches nearbyShopIdsProvider (not the raw geo-query) so it only restarts
// when the set of nearby shops changes — giving us exactly 2 listeners:
//   1. The geo-query inside nearbyShopIdsProvider  (which shops are nearby)
//   2. This whereIn stream                          (what their current data is)
//
// Individual shop data changes (isOpen toggled, rating updated) are caught
// by the whereIn stream and update the UI without restarting the geo-query
// or triggering downstream product/offer re-fetches.
final nearbyShopsProvider = StreamProvider<List<Shop>>((ref) async* {
  final idsAsync = ref.watch(nearbyShopIdsProvider);

  final userLocation = ref.read(activeBrowsingLocationProvider).value;
  final sortingLat = userLocation?.latitude ?? 0.0;
  final sortingLng = userLocation?.longitude ?? 0.0;

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

  // No IDs yet (location loading or no center) — stop after cache
  final idsString = idsAsync.value;
  if (idsString == null || idsString.isEmpty) {
    if (!hasYielded) yield <Shop>[];
    return;
  }

  final shopIds = idsString.split(',');

  // 2. Stream real-time shop data via Firestore whereIn
  try {
    final repo = ref.read(shopRepositoryProvider);
    final controller = StreamController<List<Shop>>();

    final sub = repo.streamShopsByIds(shopIds).listen(
      (shops) {
        if (controller.isClosed) return;
        // Sort by distance using the latest known location at emission time
        final loc = ref.read(activeBrowsingLocationProvider).value;
        final lat = loc?.latitude ?? sortingLat;
        final lng = loc?.longitude ?? sortingLng;
        shops.sort((a, b) {
          final dA = Geolocator.distanceBetween(
            lat, lng, a.location.latitude, a.location.longitude,
          );
          final dB = Geolocator.distanceBetween(
            lat, lng, b.location.latitude, b.location.longitude,
          );
          return dA.compareTo(dB);
        });
        controller.add(shops);
      },
      onError: (e) => debugPrint('Error in nearbyShops whereIn stream: $e'),
    );

    if (!ref.mounted) {
      sub.cancel();
      controller.close();
      return;
    }

    ref.onDispose(() {
      sub.cancel();
      controller.close();
    });

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
