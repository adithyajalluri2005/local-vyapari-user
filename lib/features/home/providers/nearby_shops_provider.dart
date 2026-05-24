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
  if (centerPoint == null) return;

  final userLocation = ref.read(activeBrowsingLocationProvider).value;
  final sortingLat = userLocation?.latitude ?? centerPoint.latitude;
  final sortingLng = userLocation?.longitude ?? centerPoint.longitude;

  // 2. Yield local cached shops immediately
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

  final center = GeoFirePoint(centerPoint);

  // 3. Subscribe to Firestore geohash bounding box stream
  final collectionRef = FirebaseFirestore.instance.collection('searchable_shops');
  final geoStream = GeoCollectionReference(collectionRef).subscribeWithin(
    center: center,
    radiusInKm: 15.0,
    field: 'geo',
    geopointFrom: (data) => (data['geo']['geopoint'] as GeoPoint),
    strictMode: true,
  );

  // 4. Yield queried values and resolve detailed RTDB models
  await for (final List<DocumentSnapshot<Map<String, dynamic>>> docs in geoStream) {
    final List<Shop> partialShops = [];
    final List<Future<Shop?>> fetchFutures = [];
    
    for (final doc in docs) {
      final shopId = doc.id;
      final data = doc.data();

      // Check if Firestore document has sufficient display data for a fast partial result
      if (data != null && (data.containsKey('shopName') || data.containsKey('name')) && (data.containsKey('shopLogo') || data.containsKey('logoUrl'))) {
        try {
          partialShops.add(Shop.fromFirestore(doc));
        } catch (e) {
          debugPrint('Failed to parse partial shop data: $e');
        }
      }

      // Parallelize full RTDB fetch
      fetchFutures.add(FirebaseDatabase.instance.ref().child('shop/$shopId').get().then((shopSnapshot) {
        if (shopSnapshot.exists && shopSnapshot.value != null) {
          final shopData = shopSnapshot.value as Map<dynamic, dynamic>;
          return Shop.fromRTDB(shopId, shopData);
        }
        return null;
      }).catchError((e) {
        debugPrint('Error fetching/parsing shop $shopId: $e');
        return null;
      }));
    }

    // Yield partial results immediately if available
    if (partialShops.isNotEmpty) {
      partialShops.sort((a, b) {
        final distA = Geolocator.distanceBetween(sortingLat, sortingLng, a.location.latitude, a.location.longitude);
        final distB = Geolocator.distanceBetween(sortingLat, sortingLng, b.location.latitude, b.location.longitude);
        return distA.compareTo(distB);
      });
      yield partialShops;
    }

    // Wait for all full RTDB details
    final results = await Future.wait(fetchFutures);
    final List<Shop> fullShops = results.whereType<Shop>().toList();

    // Sort by exact distance
    fullShops.sort((a, b) {
      final distA = Geolocator.distanceBetween(sortingLat, sortingLng, a.location.latitude, a.location.longitude);
      final distB = Geolocator.distanceBetween(sortingLat, sortingLng, b.location.latitude, b.location.longitude);
      return distA.compareTo(distB);
    });

    // 5. Cache the filtered, sorted list
    await DataCacheService.cacheShops(fullShops);
    await DataCacheService.cacheLastLocation(sortingLat, sortingLng);

    yield fullShops;
  }
});
