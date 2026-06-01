import 'dart:async';
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

final productReviewsProvider = StreamProvider.family<List<ProductReview>, String>((ref, productId) {
  ref.cacheFor(const Duration(seconds: 30));
  final service = ref.watch(reviewsServiceProvider);
  return service.getProductReviewsStream(productId);
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
  final reviewsAsync = ref.watch(productReviewsProvider(productId));
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
