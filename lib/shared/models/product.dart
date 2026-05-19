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

  factory Product.fromRTDB(String id, String shopId, Map<dynamic, dynamic> map) {
    List<String> parsedImages = [];
    if (map['images'] is List) {
      parsedImages = List<String>.from(map['images']);
    } else if (map['images'] is Map) {
      final mapImages = map['images'] as Map;
      parsedImages = mapImages.values.map((v) => v.toString()).toList();
    } else if (map['imageUrl'] != null) {
      parsedImages = [map['imageUrl'].toString()];
    }
    
    List<String> parsedKeywords = [];
    if (map['searchKeywords'] is List) {
      parsedKeywords = List<String>.from(map['searchKeywords']);
    } else if (map['searchKeywords'] is Map) {
      final mapKeywords = map['searchKeywords'] as Map;
      parsedKeywords = mapKeywords.values.map((v) => v.toString()).toList();
    }

    return Product(
      id: id,
      shopId: shopId,
      ownerId: map['ownerId'] ?? map['vendorId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      actualPrice: (map['actualPrice'] ?? map['price'] ?? 0.0).toDouble(),
      offerPrice: (map['offerPrice'] ?? map['price'] ?? 0.0).toDouble(),
      stockQuantity: map['stockQuantity'] ?? 0,
      isLowStock: map['isLowStock'] ?? false,
      isOutOfStock: map['isOutOfStock'] ?? false,
      isActive: map['isActive'] ?? true,
      images: parsedImages,
      searchKeywords: parsedKeywords,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
    );
  }
}
