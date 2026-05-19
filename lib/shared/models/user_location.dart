import 'package:cloud_firestore/cloud_firestore.dart';

class UserLocation {
  final String? id;
  final double latitude;
  final double longitude;
  final String geohash;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;
  final DateTime? createdAt;

  UserLocation({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.isDefault,
    this.createdAt,
  });

  factory UserLocation.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserLocation(
      id: doc.id,
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      geohash: data['geohash'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      pincode: data['pincode'] ?? '',
      isDefault: data['isDefault'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'isDefault': isDefault,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
