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

  // 2. Consume from repository
  try {
    final repo = ref.read(shopRepositoryProvider);
    final controller = StreamController<List<Shop>>();
    final sub = repo.getNearbyShops(
      latitude: sortingLat,
      longitude: sortingLng,
      radiusInKm: 15.0,
    ).listen((shops) {
      if (!controller.isClosed) {
        controller.add(shops);
      }
    }, onError: (e) {
      debugPrint('Error in nearbyShops repository stream: $e');
    });

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
