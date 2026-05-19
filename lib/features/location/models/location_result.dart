import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class LocationResult {
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String geohash;

  LocationResult({
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.geohash,
  });

  factory LocationResult.fromGeoapify(Map<String, dynamic> properties) {
    final name = properties['city'] ?? properties['name'] ?? properties['formatted'] ?? 'Unknown Location';
    final formattedAddress = properties['formatted'] ?? '';
    final double lat = (properties['lat'] ?? 0.0).toDouble();
    final double lon = (properties['lon'] ?? 0.0).toDouble();
    
    final geoPoint = GeoPoint(lat, lon);
    final geoFirePoint = GeoFirePoint(geoPoint);

    return LocationResult(
      name: name,
      formattedAddress: formattedAddress,
      latitude: lat,
      longitude: lon,
      geohash: geoFirePoint.geohash,
    );
  }

  factory LocationResult.fromMap(Map<String, dynamic> map) {
    return LocationResult(
      name: map['name'] ?? '',
      formattedAddress: map['formattedAddress'] ?? map['address'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      geohash: map['geohash'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'formattedAddress': formattedAddress,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}
