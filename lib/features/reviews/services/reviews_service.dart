import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_vyapari_user/features/reviews/models/shop_review.dart';
import 'package:local_vyapari_user/features/reviews/models/product_review.dart';

class ReviewsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of recent reviews for a shop
  Stream<List<ShopReview>> getShopReviewsStream(String shopId) {
    return _firestore
        .collection('shop_reviews')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ShopReview.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Stream of recent reviews for a product
  Stream<List<ProductReview>> getProductReviewsStream(String productId) {
    return _firestore
        .collection('product_reviews')
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ProductReview.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Submits or updates a shop review using a deterministic ID to prevent duplicates
  Future<void> submitShopReview({
    required String shopId,
    required String userId,
    required String userDisplayName,
    required double rating,
    required String comment,
  }) async {
    final docId = '${userId}_$shopId';
    final docRef = _firestore.collection('shop_reviews').doc(docId);

    await docRef.set({
      'userId': userId,
      'userDisplayName': userDisplayName,
      'shopId': shopId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Submits or updates a product review using a deterministic ID to prevent duplicates
  Future<void> submitProductReview({
    required String productId,
    required String userId,
    required String userDisplayName,
    required double rating,
    required String comment,
  }) async {
    final docId = '${userId}_$productId';
    final docRef = _firestore.collection('product_reviews').doc(docId);

    await docRef.set({
      'userId': userId,
      'userDisplayName': userDisplayName,
      'productId': productId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Verification logic: Check if user ordered from shop
  Future<bool> hasUserOrderedShop(String userId, String shopId) async {
    try {
      final query = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .where('shopId', isEqualTo: shopId)
          .where('status', whereIn: const ['completed', 'delivered'])
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      // In case collection is missing or empty, handle gracefully
      return false;
    }
  }

  // Verification logic: Check if user ordered product
  Future<bool> hasUserOrderedProduct(String userId, String productId) async {
    try {
      final query = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .where('productIds', arrayContains: productId)
          .where('status', whereIn: const ['completed', 'delivered'])
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      // In case collection is missing or empty, handle gracefully
      return false;
    }
  }

  // Helper to create mock orders for easy demonstration and testing
  Future<void> createMockOrder({
    required String userId,
    required String shopId,
    required List<String> productIds,
  }) async {
    await _firestore.collection('orders').add({
      'userId': userId,
      'shopId': shopId,
      'productIds': productIds,
      'status': 'completed',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get user's existing shop review if any
  Future<ShopReview?> getUserShopReview(String userId, String shopId) async {
    final docId = '${userId}_$shopId';
    final doc = await _firestore.collection('shop_reviews').doc(docId).get();
    if (doc.exists) {
      return ShopReview.fromFirestore(doc);
    }
    return null;
  }

  // Get user's existing product review if any
  Future<ProductReview?> getUserProductReview(String userId, String productId) async {
    final docId = '${userId}_$productId';
    final doc = await _firestore.collection('product_reviews').doc(docId).get();
    if (doc.exists) {
      return ProductReview.fromFirestore(doc);
    }
    return null;
  }
}
