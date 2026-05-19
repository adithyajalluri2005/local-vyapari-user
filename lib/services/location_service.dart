import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/user_location.dart';

final locationServiceProvider = Provider((ref) => LocationService());

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  Future<UserLocation?> saveUserLocation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final position = await getCurrentPosition();
      if (position == null) return null;

      String address = 'Current Location';
      String city = 'Unknown City';
      String state = '';
      String pincode = '';

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
                position.latitude, position.longitude)
            .timeout(const Duration(seconds: 5));

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address = '${place.street}, ${place.subLocality}';
          city = place.locality ?? 'Unknown City';
          state = place.administrativeArea ?? '';
          pincode = place.postalCode ?? '';
        }
      } catch (e) {
        print('Geocoding failed: $e');
      }

      final geoFirePoint = GeoFirePoint(GeoPoint(position.latitude, position.longitude));

      final userLocation = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        geohash: geoFirePoint.geohash,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        isDefault: true,
      );

      try {
        final docRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('locations')
            .doc();

        await docRef.set(userLocation.toMap()).timeout(const Duration(seconds: 5));

        await _firestore.collection('users').doc(user.uid).set({
          'activeLocationId': docRef.id,
          'lastActiveAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
      } catch (e) {
        print('Firestore save failed: $e');
      }

      return userLocation;
    } catch (e) {
      print('Location fetch error: $e');
      return null;
    }
  }
}
