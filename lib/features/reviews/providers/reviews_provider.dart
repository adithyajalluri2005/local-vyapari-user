import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/reviews/models/shop_review.dart';
import 'package:local_vyapari_user/features/reviews/models/product_review.dart';
import 'package:local_vyapari_user/features/reviews/services/reviews_service.dart';

final reviewsServiceProvider = Provider<ReviewsService>((ref) {
  return ReviewsService();
});

final shopReviewsProvider = StreamProvider.family<List<ShopReview>, String>((ref, shopId) {
  ref.cacheFor(const Duration(seconds: 30));
  final service = ref.watch(reviewsServiceProvider);
  return service.getShopReviewsStream(shopId);
});

class PaginatedReviewsState<T> {
  final List<T> reviews;
  final bool hasMore;
  final bool isLoading;
  final String? error;

  PaginatedReviewsState({
    required this.reviews,
    required this.hasMore,
    required this.isLoading,
    this.error,
  });

  PaginatedReviewsState<T> copyWith({
    List<T>? reviews,
    bool? hasMore,
    bool? isLoading,
    String? error,
  }) {
    return PaginatedReviewsState<T>(
      reviews: reviews ?? this.reviews,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class ProductReviewsNotifier extends ChangeNotifier {
  final String productId;
  DocumentSnapshot? _lastDoc;
  PaginatedReviewsState<ProductReview> state = PaginatedReviewsState(reviews: [], hasMore: true, isLoading: true);

  ProductReviewsNotifier(this.productId) {
    _fetchInitial();
  }

  Future<void> _fetchInitial() async {
    try {
      final query = FirebaseFirestore.instance
          .collection('product_reviews')
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .limit(8);
      final snapshot = await query.get();
      
      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
      }
      
      final reviews = snapshot.docs.map((doc) => ProductReview.fromFirestore(doc)).toList();
      state = state.copyWith(
        reviews: reviews,
        hasMore: snapshot.docs.length == 8,
        isLoading: false,
      );
      notifyListeners();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || _lastDoc == null) return;
    
    state = state.copyWith(isLoading: true);
    notifyListeners();
    try {
      final query = FirebaseFirestore.instance
          .collection('product_reviews')
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(8);
      final snapshot = await query.get();
      
      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
      }
      
      final newReviews = snapshot.docs.map((doc) => ProductReview.fromFirestore(doc)).toList();
      state = state.copyWith(
        reviews: [...state.reviews, ...newReviews],
        hasMore: snapshot.docs.length == 8,
        isLoading: false,
      );
      notifyListeners();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      notifyListeners();
    }
  }
}

final productReviewsProvider = Provider.autoDispose.family<ProductReviewsNotifier, String>((ref, productId) {
  final notifier = ProductReviewsNotifier(productId);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

final hasOrderedShopProvider = FutureProvider.family<bool, String>((ref, shopId) async {
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    final service = ref.watch(reviewsServiceProvider);
    return service.hasUserOrderedShop(authState.user.uid, shopId);
  }
  return false;
});

final hasOrderedProductProvider = FutureProvider.family<bool, String>((ref, productId) async {
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    final service = ref.watch(reviewsServiceProvider);
    return service.hasUserOrderedProduct(authState.user.uid, productId);
  }
  return false;
});

final userShopReviewProvider = FutureProvider.family<ShopReview?, String>((ref, shopId) async {
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    final service = ref.watch(reviewsServiceProvider);
    return service.getUserShopReview(authState.user.uid, shopId);
  }
  return null;
});

final userProductReviewProvider = FutureProvider.family<ProductReview?, String>((ref, productId) async {
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    final service = ref.watch(reviewsServiceProvider);
    return service.getUserProductReview(authState.user.uid, productId);
  }
  return null;
});

class RatingDistribution {
  final int totalCount;
  final Map<int, int> distribution;
  final double averageRating;

  RatingDistribution({
    required this.totalCount,
    required this.distribution,
    required this.averageRating,
  });
}

final shopRatingDistributionProvider = Provider.family<RatingDistribution, String>((ref, shopId) {
  final reviewsAsync = ref.watch(shopReviewsProvider(shopId));
  return reviewsAsync.maybeWhen(
    data: (reviews) {
      final Map<int, int> dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      double sum = 0;
      for (var r in reviews) {
        int rRounded = r.rating.round().clamp(1, 5);
        dist[rRounded] = (dist[rRounded] ?? 0) + 1;
        sum += r.rating;
      }
      return RatingDistribution(
        totalCount: reviews.length,
        distribution: dist,
        averageRating: reviews.isEmpty ? 0.0 : double.parse((sum / reviews.length).toStringAsFixed(1)),
      );
    },
    orElse: () => RatingDistribution(
      totalCount: 0,
      distribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      averageRating: 0.0,
    ),
  );
});

final productRatingDistributionProvider = Provider.family<RatingDistribution, String>((ref, productId) {
  final notifier = ref.watch(productReviewsProvider(productId));
  final reviews = notifier.state.reviews;
  
  if (reviews.isEmpty) {
    return RatingDistribution(
      totalCount: 0,
      distribution: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      averageRating: 0.0,
    );
  }

  final Map<int, int> dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
  double sum = 0;
  for (var r in reviews) {
    int rRounded = r.rating.round().clamp(1, 5);
    dist[rRounded] = (dist[rRounded] ?? 0) + 1;
    sum += r.rating;
  }
  return RatingDistribution(
    totalCount: reviews.length,
    distribution: dist,
    averageRating: double.parse((sum / reviews.length).toStringAsFixed(1)),
  );
});

extension CacheExtension on Ref {
  void cacheFor(Duration duration) {
    final link = keepAlive();
    Timer? timer;
    onDispose(() {
      timer?.cancel();
    });
    onCancel(() {
      timer = Timer(duration, () {
        link.close();
      });
    });
    onResume(() {
      timer?.cancel();
    });
  }
}
