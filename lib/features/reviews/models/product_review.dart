import 'package:cloud_firestore/cloud_firestore.dart';

class ProductReview {
  final String id;
  final String userId;
  final String userDisplayName;
  final String productId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  ProductReview({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.productId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ProductReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductReview(
      id: doc.id,
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? 'Anonymous User',
      productId: data['productId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'productId': productId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
