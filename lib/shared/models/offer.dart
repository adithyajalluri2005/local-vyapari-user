import 'package:cloud_firestore/cloud_firestore.dart';

class Offer {
  final String id;
  final String shopId;
  final String productId;
  final String ownerId;
  final String title;
  final String description;
  final double discountPercentage;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool isFeatured;
  final DateTime? createdAt;

  Offer({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.discountPercentage,
    this.startDate,
    this.endDate,
    required this.isActive,
    required this.isFeatured,
    this.createdAt,
  });

  factory Offer.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Offer(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      productId: data['productId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      discountPercentage: (data['discountPercentage'] ?? 0.0).toDouble(),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? false,
      isFeatured: data['isFeatured'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Offer.fromRTDB(String id, String shopId, Map<dynamic, dynamic> map) {
    return Offer(
      id: id,
      shopId: shopId,
      productId: map['productId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      discountPercentage: (map['discountPercentage'] ?? 0.0).toDouble(),
      startDate: map['startDate'] != null ? DateTime.tryParse(map['startDate'].toString()) : null,
      endDate: map['endDate'] != null ? DateTime.tryParse(map['endDate'].toString()) : null,
      isActive: map['isActive'] ?? false,
      isFeatured: map['isFeatured'] ?? false,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
    );
  }
}
