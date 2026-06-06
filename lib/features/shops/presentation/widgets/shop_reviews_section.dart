import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/app_spacing.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/features/reviews/providers/reviews_provider.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/review_card.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/rating_breakdown.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/rate_item_bottom_sheet.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';

class ShopReviewsSection extends ConsumerWidget {
  final String shopId;
  final String shopName;

  const ShopReviewsSection({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(shopReviewsProvider(shopId));
    final distribution = ref.watch(shopRatingDistributionProvider(shopId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        AppSpacing.verticalMd,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ratings & Reviews',
              style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () => _handleRateShop(context, ref),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Rate Shop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).colorScheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ),
        AppSpacing.verticalMd,
        RatingBreakdown(
          averageRating: distribution.averageRating,
          totalCount: distribution.totalCount,
          distribution: distribution.distribution,
        ),
        AppSpacing.verticalMd,
        reviewsAsync.when(
          data: (reviews) {
            if (reviews.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.rate_review_outlined, size: 48, color: AppColors.textHint),
                      const SizedBox(height: 8),
                      Text(
                        'No reviews yet',
                        style: AppTextStyles.bodyLarge(context, color: AppColors.textHint, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Be the first to share your experience!',
                        style: AppTextStyles.bodyMedium(context, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                return ReviewCard(
                  userName: review.userDisplayName,
                  rating: review.rating,
                  comment: review.comment,
                  createdAt: review.createdAt,
                );
              },
            );
          },
          loading: () => _buildReviewsShimmer(context),
          error: (error, _) => Center(child: Text('Failed to load reviews: ${error.toString()}')),
        ),
      ],
    );
  }

  Widget _buildReviewsShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase = isDark ? const Color(0xFF222C36) : Colors.grey.shade300;
    final shimmerHi = isDark ? const Color(0xFF2C3742) : Colors.grey.shade100;
    final shimmerBlock = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHi,
      child: Column(
        children: List.generate(3, (index) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: cs.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: shimmerBlock,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 100, height: 12, color: shimmerBlock),
                          const SizedBox(height: 6),
                          Container(width: 60, height: 10, color: shimmerBlock),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 20,
                      decoration: BoxDecoration(
                        color: shimmerBlock,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(width: double.infinity, height: 14, color: shimmerBlock),
                const SizedBox(height: 6),
                Container(width: double.infinity, height: 14, color: shimmerBlock),
                const SizedBox(height: 6),
                Container(width: 150, height: 14, color: shimmerBlock),
              ],
            ),
          ),
        )),
      ),
    );
  }

  Future<void> _handleRateShop(BuildContext context, WidgetRef ref) async {
    final authState = ref.read(authProvider);
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.')),
      );
      return;
    }

    _openRatingSheet(context, ref);
  }

  Future<void> _openRatingSheet(BuildContext context, WidgetRef ref) async {
    final existingReview = await ref.read(userShopReviewProvider(shopId).future);

    if (!context.mounted) return;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => RateItemBottomSheet(
        shopId: shopId,
        name: shopName,
        existingRating: existingReview?.rating,
        existingComment: existingReview?.comment,
      ),
    );

    if (submitted == true) {
      ref.invalidate(userShopReviewProvider(shopId));
    }
  }
}
