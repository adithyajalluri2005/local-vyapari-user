import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/reviews/providers/reviews_provider.dart';

class DynamicProductRating extends ConsumerWidget {
  final String productId;
  final double initialRating;
  final int initialTotalReviews;
  final Widget Function(BuildContext context, double rating, int count)? builder;
  final TextStyle? style;
  final double iconSize;
  final Color iconColor;

  const DynamicProductRating({
    super.key,
    required this.productId,
    required this.initialRating,
    required this.initialTotalReviews,
    this.builder,
    this.style,
    this.iconSize = 14,
    this.iconColor = Colors.amber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dist = ref.watch(productRatingDistributionProvider(productId));

    // Fall back to initial database values if stream is still loading/empty
    final double rating = dist.totalCount > 0 ? dist.averageRating : initialRating;
    final int count = dist.totalCount > 0 ? dist.totalCount : initialTotalReviews;

    if (builder != null) return builder!(context, rating, count);
    return _buildDefault(context, rating, count);
  }

  Widget _buildDefault(BuildContext context, double rating, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, color: iconColor, size: iconSize),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} ($count)',
          style: style ?? const TextStyle(color: Colors.grey, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
