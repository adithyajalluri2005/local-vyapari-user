import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

final nearbyShopsProvider = StreamProvider<List<Shop>>((ref) {
  final locationAsyncValue = ref.watch(activeBrowsingLocationProvider);
  final userLocation = locationAsyncValue.value;

  final dbRef = FirebaseDatabase.instance.ref('shop');
  
  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) {
      return <Shop>[];
    }
    
    final Map<dynamic, dynamic> shopsMap = snapshot.value as Map<dynamic, dynamic>;
    final List<Shop> shops = [];
    
    shopsMap.forEach((key, value) {
      if (value is Map) {
        try {
          final shopId = key.toString();
          final shopData = Map<dynamic, dynamic>.from(value);
          final shop = Shop.fromRTDB(shopId, shopData);
          if (shop.isOpen) {
            shops.add(shop);
          }
        } catch (e) {
          debugPrint('Error parsing shop $key: $e');
        }
      }
    });

    if (userLocation != null) {
      final userLat = userLocation.latitude;
      final userLng = userLocation.longitude;
      
      // Filter shops strictly within a 15km radius
      final nearbyShops = shops.where((shop) {
        final distanceInMeters = Geolocator.distanceBetween(
          userLat, userLng, shop.location.latitude, shop.location.longitude
        );
        return distanceInMeters <= 15000; // 15 km
      }).toList();

      // Sort the strictly nearby shops by distance
      nearbyShops.sort((a, b) {
        final distA = Geolocator.distanceBetween(
          userLat, userLng, a.location.latitude, a.location.longitude
        );
        final distB = Geolocator.distanceBetween(
          userLat, userLng, b.location.latitude, b.location.longitude
        );
        return distA.compareTo(distB);
      });
      
      return nearbyShops;
    }
    
    // If location is null, return empty list to prevent showing irrelevant shops
    return <Shop>[];
  }).handleError((error) {
    debugPrint('Error in nearbyShopsProvider stream: $error');
    return <Shop>[];
  });
});

