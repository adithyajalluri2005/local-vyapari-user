import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/features/favorites/presentation/widgets/favorite_button.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/favorites/providers/favorites_provider.dart';
import 'package:local_vyapari_user/features/home/providers/navigation_provider.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/shop_card.dart';
import 'package:local_vyapari_user/shared/widgets/skeleton_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favoriteProductsAsync = ref.watch(favoriteProductsProvider);
    final favoriteShopsAsync = ref.watch(favoriteShopsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          elevation: 0,
          title: Text(
            'Favourites',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textHint,
            labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
            tabs: const [
              Tab(text: 'Products'),
              Tab(text: 'Shops'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: TabBarView(
              children: [
                _buildProductsTab(context, ref, favoriteProductsAsync, isDark),
                _buildShopsTab(context, ref, favoriteShopsAsync, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Product>> productsAsync,
    bool isDark,
  ) {
    return productsAsync.when(
      loading: () => const SkeletonListView(count: 6),
      error: (_, _) => _buildError(context, isDark),
      data: (products) {
        if (products.isEmpty) {
          return _buildEmptyState(
            context,
            ref,
            icon: Icons.favorite_border_rounded,
            title: 'No favourite products yet',
            subtitle: 'Tap the heart on any product to save it here.',
          );
        }
        final hPad = Responsive.horizontalPadding(context);
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 100),
          itemCount: products.length,
          itemBuilder: (context, index) => FadeInSlide(
            delay: Duration(milliseconds: 40 * index),
            child: _ProductFavCard(product: products[index], isDark: isDark),
          ),
        );
      },
    );
  }

  Widget _buildShopsTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Shop>> shopsAsync,
    bool isDark,
  ) {
    return shopsAsync.when(
      loading: () => const SkeletonListView(count: 6),
      error: (_, _) => _buildError(context, isDark),
      data: (shops) {
        if (shops.isEmpty) {
          return _buildEmptyState(
            context,
            ref,
            icon: Icons.storefront_outlined,
            title: 'No favourite shops yet',
            subtitle: 'Tap the heart on any shop to save it here.',
          );
        }
        final hPad = Responsive.horizontalPadding(context);
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 100),
          itemCount: shops.length,
          itemBuilder: (context, index) => FadeInSlide(
            delay: Duration(milliseconds: 40 * index),
            child: ShopCard(
              shop: shops[index],
              onTap: () => context.push('/shop_details', extra: shops[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError(BuildContext context, bool isDark) {
    return Center(
      child: Text(
        'Failed to load favourites',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => ref.read(navigationIndexProvider.notifier).setIndex(0),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              child: Text(
                'Start Exploring',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product favourite card ─────────────────────────────────────────────────────

class _ProductFavCard extends StatelessWidget {
  final Product product;
  final bool isDark;

  const _ProductFavCard({required this.product, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? Colors.white10 : AppColors.border.withValues(alpha: 0.8);
    final shadow = Colors.black.withValues(alpha: isDark ? 0.2 : 0.055);
    final hasDiscount = product.actualPrice > product.offerPrice;
    final isTablet = Responsive.isTablet(context);
    final isSmall = Responsive.isSmallPhone(context);
    final imgSize = isTablet ? 84.0 : (isSmall ? 60.0 : 70.0);
    final cardPad = isTablet ? 14.0 : 12.0;

    return ScaleOnTap(
      onTap: () => context.push('/product_details', extra: product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: border, width: 0.7),
          boxShadow: [BoxShadow(color: shadow, blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: EdgeInsets.all(cardPad),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  width: imgSize,
                  height: imgSize,
                  child: product.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: product.images.first,
                          fit: BoxFit.cover,
                          cacheManager: AppCacheManager(),
                          placeholder: (_, _) => Container(color: AppColors.surfaceElevated),
                          errorWidget: (_, _, _) => Container(
                            color: AppColors.surfaceElevated,
                            child: const Icon(Icons.image_not_supported_outlined,
                                color: AppColors.textHint, size: 22),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceElevated,
                          child: const Icon(Icons.inventory_2_outlined,
                              color: AppColors.textHint, size: 22),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 15.0 : (isSmall ? 12.0 : 13.5),
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.category.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.category,
                        style: GoogleFonts.poppins(
                            fontSize: isTablet ? 12.0 : (isSmall ? 10.0 : 11.0),
                            color: AppColors.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${product.offerPrice}',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 15.5 : (isSmall ? 12.5 : 14.0),
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${product.actualPrice}',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 12.0 : (isSmall ? 10.0 : 11.0),
                              color: AppColors.textHint,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.textHint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FavoriteButton(
                itemId: product.id,
                type: FavoriteType.product,
                shopId: product.shopId,
                size: 22,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
