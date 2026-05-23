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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_shop_rating.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_product_rating.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onSearchTap;
  const HomeScreen({super.key, this.onSearchTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final locationAsync = ref.watch(activeBrowsingLocationProvider);
    final shopsAsync = ref.watch(nearbyShopsProvider);
    final productsAsync = ref.watch(nearbyProductsProvider);
    final offersAsync = ref.watch(nearbyOffersProvider);

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
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'Current Location',
                    style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
              locationAsync.when(
                data: (loc) => Text(
                  loc != null ? loc.name : 'Location not available',
                  style: AppTextStyles.bodyMedium(context, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                loading: () => Text(
                  'Fetching location...',
                  style: AppTextStyles.bodyMedium(context, color: Colors.grey),
                ),
                error: (_, __) => Text(
                  'Error fetching location',
                  style: AppTextStyles.bodyMedium(context, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotificationsBottomSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenPadding,
                  vertical: 4.0,
                ),
                child: GestureDetector(
                  onTap: onSearchTap,
                  child: AbsorbPointer(
                    child: SearchBar(
                      constraints: const BoxConstraints(minHeight: 44.0, maxHeight: 44.0),
                      hintText: 'Search for products, shops...',
                      leading: const Icon(Icons.search, color: Colors.grey, size: 20),
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: WidgetStateProperty.resolveWith((states) => Theme.of(context).colorScheme.surface),
                      textStyle: WidgetStateProperty.resolveWith((states) => AppTextStyles.bodyMedium(context)),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
                    ),
                  ),
                ),
              ),
              
              _buildSectionHeader(context, 'Trending Offers Nearby', () {}),
              SizedBox(
                height: AppSizes.offerCardHeight(context),
                child: offersAsync.when(
                  skipLoadingOnReload: false,
                  data: (offers) {
                    if (offers.isEmpty) return const Center(child: Text('No active offers nearby.'));
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
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.12),
                                AppTheme.primaryColor.withOpacity(0.02),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.paddingMedium(context),
                            vertical: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${offer.discountPercentage.toInt()}% OFF',
                                style: AppTextStyles.titleMedium(context, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                              ),
                              AppSpacing.verticalXs,
                              Text(
                                offer.title,
                                style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (offer.shopName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  offer.shopName,
                                  style: AppTextStyles.bodyMedium(context, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                offer.description,
                                style: AppTextStyles.bodyMedium(context, color: Colors.grey[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                  error: (_, __) => const Center(child: Text('Failed to load offers.')),
                ),
              ),
              
              _buildSectionHeader(context, 'Nearby Shops', () => context.push('/radar')),
              SizedBox(
                height: AppSizes.shopCardHeight(context),
                child: shopsAsync.when(
                  skipLoadingOnReload: false,
                  data: (shops) {
                    if (shops.isEmpty) return const Center(child: Text('No shops found nearby.'));
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
                              elevation: 2,
                              shadowColor: Colors.black12,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                              clipBehavior: Clip.antiAlias,
                              margin: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: shop.shopLogo.isNotEmpty ? shop.shopLogo : 'https://via.placeholder.com/150',
                                    width: cardWidth,
                                    height: AppSizes.shopImageHeight(context),
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: Colors.grey[300]!,
                                      highlightColor: Colors.grey[100]!,
                                      child: Container(color: Colors.white),
                                    ),
                                    errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.store)),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            shop.shopName,
                                            style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          DynamicShopRating(
                                            shopId: shop.id,
                                            initialRating: shop.rating,
                                            initialTotalReviews: shop.totalReviews,
                                            style: AppTextStyles.bodyMedium(context, color: Colors.grey),
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
                    return const Center(child: Text('Failed to load shops.'));
                  },
                ),
              ),
              
              _buildSectionHeader(context, 'Recommended Products', () {}),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenPadding),
                child: productsAsync.when(
                  skipLoadingOnReload: false,
                  data: (products) {
                    if (products.isEmpty) return const Center(child: Text('No products found nearby.'));
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
                        return GestureDetector(
                          onTap: () => context.push('/product_details', extra: product),
                          child: Card(
                            elevation: 2,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            clipBehavior: Clip.antiAlias,
                            margin: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.33,
                                  child: CachedNetworkImage(
                                    imageUrl: product.images.isNotEmpty ? product.images.first : 'https://via.placeholder.com/150',
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: Colors.grey[300]!,
                                      highlightColor: Colors.grey[100]!,
                                      child: Container(color: Colors.white),
                                    ),
                                    errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.image)),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                          style: AppTextStyles.bodyMedium(context, color: Colors.grey),
                                          iconSize: 12,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              '₹${product.offerPrice}',
                                              style: AppTextStyles.bodyLarge(context, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                            ),
                                            AppSpacing.horizontalSm,
                                            Flexible(
                                              child: Text(
                                                '₹${product.actualPrice}',
                                                style: AppTextStyles.bodyMedium(context, color: Colors.grey).copyWith(
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
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('Failed to load products.')),
                ),
              ),
              AppSpacing.verticalLg,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onTap) {
    final horizontalPadding = AppSizes.paddingMedium(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding, 
        12.0, 
        horizontalPadding, 
        6.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'See All',
              style: AppTextStyles.titleSmall(context, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList({required double height, required double width, required BuildContext context}) {
    final screenPadding = AppSizes.paddingMedium(context);
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: EdgeInsets.symmetric(horizontal: screenPadding),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
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

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No Notifications Yet',
                style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'You will receive notifications when shops in your neighborhood launch new offers or products.',
                style: AppTextStyles.bodyMedium(context, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
