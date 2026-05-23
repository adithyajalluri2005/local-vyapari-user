import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/core/theme/app_spacing.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_products_provider.dart';
import 'package:local_vyapari_user/features/favorites/presentation/widgets/favorite_button.dart';
import 'package:local_vyapari_user/services/analytics/analytics_service.dart';

class ShopDetailsScreen extends ConsumerStatefulWidget {
  final Shop shop;
  const ShopDetailsScreen({super.key, required this.shop});

  @override
  ConsumerState<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends ConsumerState<ShopDetailsScreen> {
  Shop get shop => widget.shop;
  final _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _analyticsService.trackShopView(shop.ownerId);
  }

  Future<void> _launchMaps(BuildContext context) async {
    _analyticsService.trackProfileClick(shop.ownerId);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${shop.location.latitude},${shop.location.longitude}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps')));
      }
    }
  }
  
  Future<void> _callShop(BuildContext context) async {
    _analyticsService.trackProfileClick(shop.ownerId);
    final url = Uri.parse('tel:${shop.phone}');
    try {
      await launchUrl(url);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open dialer')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final productsAsync = ref.watch(shopProductsProvider(shop.id));
    final padding = AppSizes.paddingMedium(context);

    if (Responsive.isTablet(context)) {
      // Split side-by-side layout for tablets
      return Scaffold(
        appBar: AppBar(
          title: Text(
            shop.shopName,
            style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column - Shop Banner, details & Actions
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: AspectRatio(
                          aspectRatio: 1.6,
                          child: CachedNetworkImage(
                            imageUrl: shop.shopLogo.isNotEmpty ? shop.shopLogo : (shop.shopBanner.isNotEmpty ? shop.shopBanner : 'https://via.placeholder.com/600x300'),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.store, size: 50)),
                          ),
                        ),
                      ),
                      AppSpacing.verticalMd,
                      _buildShopTitleRow(context),
                      AppSpacing.verticalSm,
                      _buildStatusAndRatingRow(context),
                      AppSpacing.verticalMd,
                      Text(
                        shop.description,
                        style: AppTextStyles.bodyLarge(context, color: Colors.grey[800]),
                      ),
                      AppSpacing.verticalMd,
                      _buildAddressAndContact(context),
                      AppSpacing.verticalLg,
                      _buildActionButtons(context),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              // Right Column - Products list
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(padding, padding, padding, 8),
                      child: Text(
                        'Available Products',
                        style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: productsAsync.when(
                        data: (products) {
                          if (products.isEmpty) {
                            return const Center(child: Text('No products available for this shop.'));
                          }
                          return GridView.builder(
                            padding: EdgeInsets.all(padding),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: padding,
                              mainAxisSpacing: padding,
                              childAspectRatio: AppSizes.productGridAspectRatio(context),
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(context, products[index]);
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(child: Text('Failed to load products', style: AppTextStyles.bodyLarge(context))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default Mobile Sliver Layout
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: shop.shopLogo.isNotEmpty ? shop.shopLogo : (shop.shopBanner.isNotEmpty ? shop.shopBanner : 'https://via.placeholder.com/600x300'),
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.store, size: 50)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShopTitleRow(context),
                  AppSpacing.verticalSm,
                  _buildStatusAndRatingRow(context),
                  AppSpacing.verticalMd,
                  Text(
                    shop.description,
                    style: AppTextStyles.bodyLarge(context, color: Colors.grey[800]),
                  ),
                  AppSpacing.verticalMd,
                  _buildAddressAndContact(context),
                  AppSpacing.verticalLg,
                  _buildActionButtons(context),
                  AppSpacing.verticalLg,
                  Text(
                    'Available Products',
                    style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
                  ),
                  AppSpacing.verticalMd,
                  productsAsync.when(
                    data: (products) {
                      if (products.isEmpty) return const Center(child: Text('No products available for this shop.'));
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: AppSizes.productGridColumnCount(context),
                          crossAxisSpacing: padding,
                          mainAxisSpacing: padding,
                          childAspectRatio: AppSizes.productGridAspectRatio(context),
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(context, products[index]);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(child: Text('Failed to load products', style: AppTextStyles.bodyLarge(context))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopTitleRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  shop.shopName,
                  style: AppTextStyles.titleLarge(context, fontWeight: FontWeight.bold),
                ),
              ),
              if (shop.isVerified) ...[
                AppSpacing.horizontalSm,
                const Icon(Icons.verified, color: Colors.blue, size: 24),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        FavoriteButton(
          itemId: shop.id,
          type: FavoriteType.shop,
        ),
      ],
    );
  }

  Widget _buildStatusAndRatingRow(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: shop.isOpen ? AppTheme.successColor.withOpacity(0.1) : AppTheme.errorColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            shop.isOpen ? 'OPEN' : 'CLOSED',
            style: TextStyle(
              color: shop.isOpen ? AppTheme.successColor : AppTheme.errorColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        AppSpacing.horizontalMd,
        const Icon(Icons.star, color: Colors.amber, size: 20),
        const SizedBox(width: 4),
        Text(
          '${shop.rating} (${shop.totalReviews} reviews)',
          style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAddressAndContact(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shop.location.address.isNotEmpty || shop.location.city.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.grey, size: 20),
              AppSpacing.horizontalSm,
              Expanded(
                child: Text(
                  shop.location.address.isNotEmpty ? shop.location.address : shop.location.city,
                  style: AppTextStyles.bodyLarge(context, color: Colors.grey[800]),
                ),
              ),
            ],
          ),
        if (shop.phone.isNotEmpty) ...[
          AppSpacing.verticalSm,
          Row(
            children: [
              const Icon(Icons.phone, color: Colors.grey, size: 20),
              AppSpacing.horizontalSm,
              Text(
                shop.phone,
                style: AppTextStyles.bodyLarge(context, color: Colors.grey[800]),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _callShop(context),
                icon: const Icon(Icons.call),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ),
            AppSpacing.horizontalMd,
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _launchMaps(context),
                icon: const Icon(Icons.directions),
                label: const Text('Navigate'),
              ),
            ),
          ],
        ),
        AppSpacing.verticalSm,
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _analyticsService.trackProfileClick(shop.ownerId);
              context.push('/chat', extra: {
                'shopId': shop.id,
                'shopName': shop.shopName,
                'shopLogo': shop.shopLogo,
              });
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chat with Vendor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, dynamic product) {
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
                  const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }
}
