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
import 'package:local_vyapari_user/features/reviews/providers/reviews_provider.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_shop_rating.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_product_rating.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/review_card.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/rating_breakdown.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/rate_item_bottom_sheet.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';

class ShopDetailsScreen extends ConsumerStatefulWidget {
  final Shop shop;
  const ShopDetailsScreen({super.key, required this.shop});

  @override
  ConsumerState<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends ConsumerState<ShopDetailsScreen> {
  late Shop _shop;
  Shop get shop => _shop;
  final _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _shop = widget.shop;
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
    _shop = ref.watch(shopDetailsStreamProvider(widget.shop.id)).value ?? widget.shop;
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
                      AppSpacing.verticalLg,
                      _buildReviewsSection(context),
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
                  AppSpacing.verticalLg,
                  _buildReviewsSection(context),
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
    String timingText = '';
    if (shop.isOpen) {
      timingText = 'OPEN';
      if (shop.closingTime != null && shop.closingTime!.isNotEmpty) {
        timingText += ' • Closes at ${shop.closingTime}';
      }
    } else {
      timingText = 'CLOSED';
      if (shop.openingTime != null && shop.openingTime!.isNotEmpty) {
        timingText += ' • Opens at ${shop.openingTime}';
      }
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: shop.isOpen ? AppTheme.successColor.withOpacity(0.1) : AppTheme.errorColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            timingText,
            style: TextStyle(
              color: shop.isOpen ? AppTheme.successColor : AppTheme.errorColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        AppSpacing.horizontalMd,
        DynamicShopRating(
          shopId: shop.id,
          initialRating: shop.rating,
          initialTotalReviews: shop.totalReviews,
          builder: (context, rating, reviewsCount) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${rating.toStringAsFixed(1)} ($reviewsCount ratings)',
                  style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.w500),
                ),
              ],
            );
          },
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
                  const SizedBox(height: 2),
                  DynamicProductRating(
                    productId: product.id,
                    initialRating: product.rating,
                    initialTotalReviews: product.totalReviews,
                    style: AppTextStyles.bodyMedium(context, color: Colors.grey),
                    iconSize: 12,
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

  Widget _buildReviewsSection(BuildContext context) {
    final reviewsAsync = ref.watch(shopReviewsProvider(shop.id));
    final distribution = ref.watch(shopRatingDistributionProvider(shop.id));

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
              onPressed: () => _handleRateShop(context),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Rate Shop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                foregroundColor: AppTheme.primaryColor,
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
                      Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text(
                        'No reviews yet',
                        style: AppTextStyles.bodyLarge(context, color: Colors.grey[600], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Be the first to share your experience!',
                        style: AppTextStyles.bodyMedium(context, color: Colors.grey[400]),
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
          error: (error, _) => Center(child: Text('Failed to load reviews: $error')),
        ),
      ],
    );
  }

  Widget _buildReviewsShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(3, (index) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 100,
                            height: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 60,
                            height: 10,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 14,
                  color: Colors.white,
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  height: 14,
                  color: Colors.white,
                ),
                const SizedBox(height: 6),
                Container(
                  width: 150,
                  height: 14,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }

  Future<void> _handleRateShop(BuildContext context) async {
    final authState = ref.read(authProvider);
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.')),
      );
      return;
    }

    _openRatingSheet(context);
  }

  Future<void> _openRatingSheet(BuildContext context) async {
    final existingReview = await ref.read(userShopReviewProvider(shop.id).future);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => RateItemBottomSheet(
        shopId: shop.id,
        name: shop.shopName,
        existingRating: existingReview?.rating,
        existingComment: existingReview?.comment,
      ),
    );
  }
}
