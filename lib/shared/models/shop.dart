import 'package:cloud_firestore/cloud_firestore.dart';

class Shop {
  final String id;
  final String ownerId;
  final String shopName;
  final String description;
  final String phone;
  final String shopLogo;
  final String shopBanner;
  final bool isVerified;
  final bool isOpen;
  final double rating;
  final int totalReviews;
  final DateTime? createdAt;
  final ShopLocation location;

  Shop({
    required this.id,
    required this.ownerId,
    required this.shopName,
    required this.description,
    required this.phone,
    required this.shopLogo,
    required this.shopBanner,
    required this.isVerified,
    required this.isOpen,
    required this.rating,
    required this.totalReviews,
    this.createdAt,
    required this.location,
  });

  factory Shop.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Shop(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      shopName: data['shopName'] ?? '',
      description: data['description'] ?? '',
      phone: data['phone'] ?? '',
      shopLogo: data['shopLogo'] ?? '',
      shopBanner: data['shopBanner'] ?? '',
      isVerified: data['isVerified'] ?? false,
      isOpen: data['isOpen'] ?? false,
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalReviews: data['totalReviews'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      location: ShopLocation.fromMap(data['location'] ?? {}),
    );
  }

  factory Shop.fromRTDB(String id, Map<dynamic, dynamic> map) {
    final String addressStr = map['address'] ?? '';
    
    // Attempt to extract city from address (e.g. "Venkatarayapuram, Tanuku, ...")
    String cityStr = map['city'] ?? '';
    if (cityStr.isEmpty && addressStr.isNotEmpty) {
      final parts = addressStr.split(',').map((p) => p.trim()).toList();
      if (parts.length >= 3) {
        // usually format is: street, area, city, pincode, country
        cityStr = parts[2];
      } else if (parts.isNotEmpty) {
        cityStr = parts.last;
      }
    }
    if (cityStr.isEmpty) {
      cityStr = 'Unknown City';
    }

    return Shop(
      id: id,
      ownerId: map['ownerId'] ?? map['id'] ?? id,
      shopName: map['name'] ?? map['shopName'] ?? '',
      description: map['description'] ?? '',
      phone: map['phone'] ?? '',
      shopLogo: map['logoUrl'] ?? map['shopLogo'] ?? '',
      shopBanner: map['bannerUrl'] ?? map['shopBanner'] ?? '',
      isVerified: map['isVerified'] ?? false,
      isOpen: map['isOpen'] ?? true,
      rating: (map['rating'] ?? 0.0).toDouble(),
      totalReviews: map['totalReviews'] ?? 0,
      createdAt: map['createdAt'] != null 
          ? DateTime.tryParse(map['createdAt'].toString()) 
          : null,
      location: ShopLocation(
        latitude: (map['latitude'] ?? 0.0).toDouble(),
        longitude: (map['longitude'] ?? 0.0).toDouble(),
        geohash: map['geohash'] ?? '',
        address: addressStr,
        city: cityStr,
        state: map['state'] ?? '',
        pincode: map['pincode'] ?? '',
        placeId: map['placeId'] ?? '',
      ),
    );
  }
}

class ShopLocation {
  final double latitude;
  final double longitude;
  final String geohash;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String placeId;

  ShopLocation({
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.placeId,
  });

  factory ShopLocation.fromMap(Map<String, dynamic> map) {
    return ShopLocation(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      geohash: map['geohash'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
      placeId: map['placeId'] ?? '',
    );
  }
}
