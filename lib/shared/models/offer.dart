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
}
