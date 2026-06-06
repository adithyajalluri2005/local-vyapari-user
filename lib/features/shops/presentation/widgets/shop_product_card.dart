import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/core/theme/app_spacing.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_product_rating.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';

class ShopProductCard extends StatelessWidget {
  final dynamic product;

  const ShopProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/product_details', extra: product),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                child: CachedNetworkImage(
                  imageUrl: product.images.isNotEmpty ? product.images.first : '',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheManager: AppCacheManager(),
                  placeholder: (ctx, url) {
                    final isDark = Theme.of(ctx).brightness == Brightness.dark;
                    return Shimmer.fromColors(
                      baseColor: isDark ? const Color(0xFF222C36) : Colors.grey.shade300,
                      highlightColor: isDark ? const Color(0xFF2C3742) : Colors.grey.shade100,
                      child: Container(color: isDark ? const Color(0xFF1E1E2E) : Colors.white),
                    );
                  },
                  errorWidget: (ctx, url, error) => Container(color: Theme.of(ctx).colorScheme.surfaceContainerHighest, child: const Icon(Icons.image)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSizes.paddingSmall(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  DynamicProductRating(
                    productId: product.id,
                    initialRating: product.rating,
                    initialTotalReviews: product.totalReviews,
                    style: AppTextStyles.bodyMedium(context, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    iconSize: 12,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${product.offerPrice}',
                        style: AppTextStyles.bodyLarge(
                          context,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.horizontalSm,
                      Flexible(
                        child: Text(
                          '₹${product.actualPrice}',
                          style: AppTextStyles.bodyMedium(context, color: AppColors.textHint).copyWith(
                            decoration: TextDecoration.lineThrough,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
