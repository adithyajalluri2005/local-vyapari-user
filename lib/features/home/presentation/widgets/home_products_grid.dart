import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_products_provider.dart';
import 'package:local_vyapari_user/shared/widgets/skeleton_card.dart';
import 'package:local_vyapari_user/features/favorites/presentation/widgets/favorite_button.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_product_rating.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/widgets/empty_section.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';

class ProductsGrid extends ConsumerWidget {
  final bool isDark;
  final int visibleCount;
  const ProductsGrid({super.key, required this.isDark, required this.visibleCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(nearbyProductsProvider);
    final cols = Responsive.productGridColumns(context);
    final aspectRatio = AppSizes.productGridAspectRatio(context);

    return productsAsync.when(
      skipLoadingOnReload: false,
      data: (products) {
        if (products.isEmpty) {
          return const EmptySection(
            icon: Icons.inventory_2_outlined,
            message: 'No products found nearby',
          );
        }
        final visible = products.take(visibleCount).toList();
        final hasMore = products.length > visibleCount;
        return Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: aspectRatio,
              ),
              itemCount: visible.length,
              itemBuilder: (ctx, i) {
                final p = visible[i];
                final hasDiscount = p.actualPrice > p.offerPrice;
                final discPct = hasDiscount
                    ? ((1 - p.offerPrice / p.actualPrice) * 100).toInt()
                    : 0;
                final bg = isDark ? AppColors.darkSurface : AppColors.surface;
                final border = isDark
                    ? Colors.white10
                    : AppColors.border.withValues(alpha: 0.8);
                final shadow = Colors.black.withValues(
                  alpha: isDark ? 0.2 : 0.055,
                );

                return FadeInSlide(
                  delay: Duration(milliseconds: 50 * i),
                  child: ScaleOnTap(
                    onTap: () => context.push('/product_details', extra: p),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: border, width: 0.7),
                        boxShadow: [
                          BoxShadow(
                            color: shadow,
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 1.1,
                                child: p.images.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: p.images.first,
                                        fit: BoxFit.cover,
                                        cacheManager: AppCacheManager(),
                                        placeholder: (_, _) => Container(
                                          color: AppColors.surfaceElevated,
                                        ),
                                        errorWidget: (_, _, _) => Container(
                                          color: AppColors.surfaceElevated,
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
                                            color: AppColors.textHint,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: AppColors.surfaceElevated,
                                        child: const Icon(
                                          Icons.inventory_2_outlined,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                              ),
                              if (hasDiscount)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: Text(
                                      '$discPct% off',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: FavoriteButton(
                                      itemId: p.id,
                                      type: FavoriteType.product,
                                      shopId: p.shopId,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: Responsive.isTablet(context) ? 13.5 : (Responsive.isSmallPhone(context) ? 11.5 : 12.5),
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (p.category.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          p.category,
                                          style: GoogleFonts.poppins(
                                            fontSize: Responsive.isTablet(context) ? 11.0 : (Responsive.isSmallPhone(context) ? 9.5 : 10.0),
                                            color: AppColors.textHint,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      DynamicProductRating(
                                        productId: p.id,
                                        initialRating: p.rating,
                                        initialTotalReviews: p.totalReviews,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          color: AppColors.textHint,
                                        ),
                                        iconSize: 11,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '₹${p.offerPrice}',
                                            style: GoogleFonts.poppins(
                                              fontSize: Responsive.isTablet(context) ? 15.0 : (Responsive.isSmallPhone(context) ? 13.0 : 14.0),
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : AppColors.primary,
                                            ),
                                          ),
                                          if (hasDiscount) ...[
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '₹${p.actualPrice}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: Responsive.isTablet(context) ? 12.0 : (Responsive.isSmallPhone(context) ? 10.0 : 11.0),
                                                  color: AppColors.textHint,
                                                  decoration:
                                                      TextDecoration.lineThrough,
                                                  decorationColor:
                                                      AppColors.textHint,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SkeletonProductGrid(
                  crossAxisCount: cols,
                  aspectRatio: aspectRatio,
                  spacing: 10,
                  rowCount: 1,
                ),
              ),
          ],
        );
      },
      loading: () => SkeletonProductGrid(
        crossAxisCount: cols,
        aspectRatio: aspectRatio,
        spacing: 10,
      ),
      error: (_, _) => const EmptySection(
        icon: Icons.error_outline,
        message: 'Could not load products',
      ),
    );
  }
}
