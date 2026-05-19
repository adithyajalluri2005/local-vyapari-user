import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:local_vyapari_user/services/location_service.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/models/user_location.dart';

final currentLocationProvider = FutureProvider<UserLocation?>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.saveUserLocation();
});

final nearbyShopsProvider = StreamProvider<List<Shop>>((ref) {
  final locationAsyncValue = ref.watch(currentLocationProvider);
  
  return locationAsyncValue.when(
    data: (userLocation) {
      if (userLocation == null) return Stream.value([]);

      final geoPoint = GeoPoint(userLocation.latitude, userLocation.longitude);
      final center = GeoFirePoint(geoPoint);
      final radiusInKm = 5.0;

      final collectionRef = FirebaseFirestore.instance.collection('shops');

      return GeoCollectionReference(collectionRef).subscribeWithin(
        center: center,
        radiusInKm: radiusInKm,
        field: 'location',
        queryBuilder: (query) => query
            .where('isOpen', isEqualTo: true)
            .where('isVerified', isEqualTo: true),
        geopointFrom: (doc) {
          final loc = doc['location'] as Map<String, dynamic>;
          return GeoPoint(loc['latitude'], loc['longitude']);
        },
        strictMode: true,
      ).map((docs) {
        return docs.map((doc) => Shop.fromFirestore(doc)).toList();
      });
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});
