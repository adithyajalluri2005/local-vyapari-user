import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

class LastQueryCenterNotifier extends Notifier<GeoPoint?> {
  @override
  GeoPoint? build() => null;
  void setCenter(GeoPoint? center) => state = center;
}
final lastQueryCenterProvider = NotifierProvider<LastQueryCenterNotifier, GeoPoint?>(LastQueryCenterNotifier.new);

final queryCenterProvider = Provider<GeoPoint?>((ref) {
  final loc = ref.watch(activeBrowsingLocationProvider).value;
  if (loc == null) return null;
  
  final lastCenter = ref.read(lastQueryCenterProvider);
  if (lastCenter != null) {
    final dist = Geolocator.distanceBetween(
      loc.latitude, loc.longitude, 
      lastCenter.latitude, lastCenter.longitude
    );
    if (dist <= 300) {
      return lastCenter; // Return same instance to prevent dependent rebuilds
    }
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

  // 1. Yield local cached shops immediately
  try {
    final cached = await DataCacheService.getCachedShops();
    final cachedLocation = await DataCacheService.getCachedLastLocation();
    if (cached.isNotEmpty && cachedLocation != null) {
      final distance = Geolocator.distanceBetween(
        sortingLat,
        sortingLng,
        cachedLocation['latitude']!,
        cachedLocation['longitude']!,
      );
      if (distance <= 15000) {
        yield cached;
      }
    }
  } catch (e) {
    debugPrint('Error yielding cached shops: $e');
  }

  // 2. Stream from Firebase Realtime Database
  final shopRef = FirebaseDatabase.instance.ref('shop');
  
  await for (final event in shopRef.onValue) {
    final snapshot = event.snapshot;
    final List<Shop> shops = [];
    if (snapshot.exists && snapshot.value != null) {
      try {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          try {
            final shopId = key.toString();
            final shopData = Map<dynamic, dynamic>.from(value as Map);
            final shop = Shop.fromRTDB(shopId, shopData);
            
            // Calculate distance in km
            final distance = Geolocator.distanceBetween(
              sortingLat,
              sortingLng,
              shop.location.latitude,
              shop.location.longitude,
            ) / 1000.0;
            
            // Filter within 15 km
            if (distance <= 15.0) {
              shops.add(shop);
            }
          } catch (e) {
            debugPrint('Error parsing shop item: $e');
          }
        });
        
        // Sort by distance
        shops.sort((a, b) {
          final distA = Geolocator.distanceBetween(sortingLat, sortingLng, a.location.latitude, a.location.longitude);
          final distB = Geolocator.distanceBetween(sortingLat, sortingLng, b.location.latitude, b.location.longitude);
          return distA.compareTo(distB);
        });

        // Cache the results
        await DataCacheService.cacheShops(shops);
        await DataCacheService.cacheLastLocation(sortingLat, sortingLng);
      } catch (e) {
        debugPrint('Error parsing shops: $e');
      }
    }
    yield shops;
  }
});
