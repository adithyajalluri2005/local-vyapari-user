import 'package:cloud_firestore/cloud_firestore.dart';

class ShopReview {
  final String id;
  final String userId;
  final String userDisplayName;
  final String shopId;
  final double rating;
  final String comment;
  final DateTime createdAt;

  ShopReview({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.shopId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ShopReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopReview(
      id: doc.id,
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? 'Anonymous User',
      shopId: data['shopId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userDisplayName': userDisplayName,
      'shopId': shopId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
