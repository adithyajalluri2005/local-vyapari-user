import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String shopId;
  final String ownerId;
  final String name;
  final String description;
  final String category;
  final double actualPrice;
  final double offerPrice;
  final int stockQuantity;
  final bool isLowStock;
  final bool isOutOfStock;
  final bool isActive;
  final List<String> images;
  final List<String> searchKeywords;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.shopId,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.category,
    required this.actualPrice,
    required this.offerPrice,
    required this.stockQuantity,
    required this.isLowStock,
    required this.isOutOfStock,
    required this.isActive,
    required this.images,
    required this.searchKeywords,
    this.createdAt,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      shopId: data['shopId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      actualPrice: (data['actualPrice'] ?? 0.0).toDouble(),
      offerPrice: (data['offerPrice'] ?? 0.0).toDouble(),
      stockQuantity: data['stockQuantity'] ?? 0,
      isLowStock: data['isLowStock'] ?? false,
      isOutOfStock: data['isOutOfStock'] ?? false,
      isActive: data['isActive'] ?? false,
      images: List<String>.from(data['images'] ?? []),
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
