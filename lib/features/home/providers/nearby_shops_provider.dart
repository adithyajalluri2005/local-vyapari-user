import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

final nearbyShopsProvider = StreamProvider<List<Shop>>((ref) async* {
  // 1. Watch active location changes first
  final locationAsyncValue = ref.watch(activeBrowsingLocationProvider);
  final userLocation = locationAsyncValue.value;

  if (userLocation == null) {
    return;
  }

  // 2. Yield local cached shops immediately if they match the active location (within 15km)
  try {
    final cached = await DataCacheService.getCachedShops();
    if (cached.isNotEmpty) {
      final firstShop = cached.first;
      final distance = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        firstShop.location.latitude,
        firstShop.location.longitude,
      );
      if (distance <= 15000) {
        yield cached;
      }
    }
  } catch (e) {
    debugPrint('Error yielding cached shops: $e');
  }

  final center = GeoFirePoint(GeoPoint(userLocation.latitude, userLocation.longitude));

  // 3. Subscribe to Firestore geohash bounding box stream (only queries/listens within 15km)
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
    final List<Shop> shops = [];
    
    for (final doc in docs) {
      final shopId = doc.id;
      try {
        final shopSnapshot = await FirebaseDatabase.instance.ref().child('shop/$shopId').get();
        if (shopSnapshot.exists && shopSnapshot.value != null) {
          final shopData = shopSnapshot.value as Map<dynamic, dynamic>;
          final shop = Shop.fromRTDB(shopId, shopData);
          if (shop.isOpen) {
            shops.add(shop);
          }
        }
      } catch (e) {
        debugPrint('Error fetching/parsing shop $shopId: $e');
      }
    }

    // Sort by exact distance
    shops.sort((a, b) {
      final distA = Geolocator.distanceBetween(
        userLocation.latitude, userLocation.longitude, a.location.latitude, a.location.longitude
      );
      final distB = Geolocator.distanceBetween(
        userLocation.latitude, userLocation.longitude, b.location.latitude, b.location.longitude
      );
      return distA.compareTo(distB);
    });

    // 5. Cache the filtered, sorted list
    await DataCacheService.cacheShops(shops);

    yield shops;
  }
});
