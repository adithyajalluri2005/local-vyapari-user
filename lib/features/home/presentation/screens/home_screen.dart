import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/core/theme/app_spacing.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_products_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_shop_rating.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_product_rating.dart';
import 'package:local_vyapari_user/shared/widgets/app_network_image.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onSearchTap;
  const HomeScreen({super.key, this.onSearchTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final locationAsync = ref.watch(activeBrowsingLocationProvider);

    ref.listen(activeBrowsingLocationProvider, (previous, next) {
      if (previous?.value != next?.value) {
        ref.invalidate(nearbyShopsProvider);
        ref.invalidate(nearbyProductsProvider);
        ref.invalidate(nearbyOffersProvider);
      }
    });

    final screenPadding = AppSizes.paddingMedium(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 4.0),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.storefront,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
        ),
        title: GestureDetector(
          onTap: () => context.push('/location_search'),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DELIVER TO',
                style: AppTextStyles.bodyMedium(
                  context,
                  color: AppTheme.inkFaint,
                  fontWeight: FontWeight.w600,
                ).copyWith(letterSpacing: 0.6, fontSize: 10),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: locationAsync.when(
                      data: (loc) => Text(
                        loc != null ? loc.name : 'Set your location',
                        style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      loading: () => Text(
                        'Fetching location…',
                        style: AppTextStyles.titleSmall(context, color: AppTheme.inkMuted),
                      ),
                      error: (_, __) => Text(
                        'Location unavailable',
                        style: AppTextStyles.titleSmall(context, color: AppTheme.inkMuted),
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.inkMuted),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
            onPressed: () => _showNotificationsBottomSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(screenPadding, 8.0, screenPadding, 4.0),
                child: GestureDetector(
                  onTap: onSearchTap,
                  child: AbsorbPointer(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: AppTheme.inkMuted, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Search products, shops…',
                            style: AppTextStyles.bodyLarge(context, color: AppTheme.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              _buildSectionHeader(context, 'Trending offers nearby'),
              _OffersSection(screenPadding: screenPadding),

              _buildSectionHeader(context, 'Shops near you', onTap: () => context.push('/radar')),
              _ShopsSection(screenPadding: screenPadding),

              _buildSectionHeader(context, 'Recommended for you'),
              _ProductsSection(screenPadding: screenPadding),
              AppSpacing.verticalLg,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {VoidCallback? onTap}) {
    final horizontalPadding = AppSizes.paddingMedium(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 20.0, horizontalPadding, 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.w700),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: AppTextStyles.titleSmall(context, color: AppTheme.primaryColor),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.primaryColor),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 36, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                'No notifications yet',
                style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ll be notified when shops near you launch new offers or products.',
                style: AppTextStyles.bodyMedium(context, color: AppTheme.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OffersSection extends ConsumerWidget {
  final double screenPadding;
  const _OffersSection({required this.screenPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(nearbyOffersProvider);
    return SizedBox(
      height: AppSizes.offerCardHeight(context),
      child: offersAsync.when(
        skipLoadingOnReload: false,
        data: (offers) {
          if (offers.isEmpty) {
            return _EmptyHint(
              icon: Icons.local_offer_outlined,
              message: 'No active offers nearby yet',
            );
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: screenPadding),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              return Container(
                width: AppSizes.offerCardWidth(context),
                margin: EdgeInsets.only(right: screenPadding),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        '${offer.discountPercentage.toInt()}% OFF',
                        style: AppTextStyles.bodyMedium(
                          context,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.title,
                          style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (offer.shopName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined, size: 13, color: AppTheme.inkMuted),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  offer.shopName,
                                  style: AppTextStyles.bodyMedium(context, color: AppTheme.inkMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => _buildShimmerList(
          height: AppSizes.offerCardHeight(context),
          width: AppSizes.offerCardWidth(context),
          context: context,
        ),
        error: (_, _) => _EmptyHint(icon: Icons.error_outline, message: 'Couldn\'t load offers'),
      ),
    );
  }
}

class _ShopsSection extends ConsumerWidget {
  final double screenPadding;
  const _ShopsSection({required this.screenPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(nearbyShopsProvider);
    return SizedBox(
      height: AppSizes.shopCardHeight(context),
      child: shopsAsync.when(
        skipLoadingOnReload: false,
        data: (shops) {
          if (shops.isEmpty) {
            return _EmptyHint(icon: Icons.storefront_outlined, message: 'No shops found nearby');
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: screenPadding),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shop = shops[index];
              final cardWidth = AppSizes.shopCardWidth(context);
              return GestureDetector(
                onTap: () => context.push('/shop_details', extra: shop),
                child: Container(
                  width: cardWidth,
                  margin: EdgeInsets.only(right: screenPadding),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppNetworkImage(
                          url: shop.shopLogo,
                          width: cardWidth,
                          height: AppSizes.shopImageHeight(context),
                          fallbackIcon: Icons.storefront_outlined,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  shop.shopName,
                                  style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    _StatusDot(isOpen: shop.isOpen),
                                    AppSpacing.horizontalSm,
                                    Expanded(
                                      child: DynamicShopRating(
                                        shopId: shop.id,
                                        initialRating: shop.rating,
                                        initialTotalReviews: shop.totalReviews,
                                        style: AppTextStyles.bodyMedium(context, color: AppTheme.inkMuted),
                                      ),
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
          );
        },
        loading: () => _buildShimmerList(
          height: AppSizes.shopCardHeight(context),
          width: AppSizes.shopCardWidth(context),
          context: context,
        ),
        error: (error, stackTrace) {
          debugPrint('Error loading shops on home screen: $error\n$stackTrace');
          return _EmptyHint(icon: Icons.error_outline, message: 'Couldn\'t load shops');
        },
      ),
    );
  }
}

class _ProductsSection extends ConsumerWidget {
  final double screenPadding;
  const _ProductsSection({required this.screenPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(nearbyProductsProvider);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenPadding),
      child: productsAsync.when(
        skipLoadingOnReload: false,
        data: (products) {
          if (products.isEmpty) {
            return _EmptyHint(icon: Icons.inventory_2_outlined, message: 'No products found nearby');
          }
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppSizes.productGridColumnCount(context),
              crossAxisSpacing: screenPadding,
              mainAxisSpacing: screenPadding,
              childAspectRatio: AppSizes.productGridAspectRatio(context),
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final hasDiscount = product.actualPrice > product.offerPrice;
              return GestureDetector(
                onTap: () => context.push('/product_details', extra: product),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1.33,
                        child: AppNetworkImage(
                          url: product.images.isNotEmpty ? product.images.first : '',
                          width: double.infinity,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                product.name,
                                style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              DynamicProductRating(
                                productId: product.id,
                                initialRating: product.rating,
                                initialTotalReviews: product.totalReviews,
                                style: AppTextStyles.bodyMedium(context, color: AppTheme.inkMuted),
                                iconSize: 12,
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '₹${product.offerPrice}',
                                    style: AppTextStyles.bodyLarge(context, color: AppTheme.ink, fontWeight: FontWeight.w700),
                                  ),
                                  if (hasDiscount) ...[
                                    AppSpacing.horizontalSm,
                                    Flexible(
                                      child: Text(
                                        '₹${product.actualPrice}',
                                        style: AppTextStyles.bodyMedium(context, color: AppTheme.inkFaint).copyWith(
                                          decoration: TextDecoration.lineThrough,
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
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
        error: (_, _) => _EmptyHint(icon: Icons.error_outline, message: 'Couldn\'t load products'),
      ),
    );
  }
}

Widget _buildShimmerList({required double height, required double width, required BuildContext context}) {
  final screenPadding = AppSizes.paddingMedium(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return ListView.builder(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    padding: EdgeInsets.symmetric(horizontal: screenPadding),
    itemCount: 3,
    itemBuilder: (context, index) {
      return Shimmer.fromColors(
        baseColor: isDark ? const Color(0xFF222C36) : const Color(0xFFE9ECEF),
        highlightColor: isDark ? const Color(0xFF2C3742) : const Color(0xFFF4F6F8),
        child: Container(
          width: width,
          height: height,
          margin: EdgeInsets.only(right: screenPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    },
  );
}

/// A compact open/closed status pill used on shop cards.
class _StatusDot extends StatelessWidget {
  final bool isOpen;
  const _StatusDot({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppTheme.successColor : AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.circular),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'Open' : 'Closed',
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A quiet inline empty/error state for the horizontal home sections.
class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyHint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.inkFaint, size: 26),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodyMedium(context, color: AppTheme.inkMuted),
          ),
        ],
      ),
    );
  }
}
