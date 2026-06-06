import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/core/theme/app_spacing.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/features/products/providers/product_details_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';
import 'package:local_vyapari_user/features/favorites/presentation/widgets/favorite_button.dart';
import 'package:local_vyapari_user/features/reviews/providers/reviews_provider.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_product_rating.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_shop_rating.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/review_card.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/rating_breakdown.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/rate_item_bottom_sheet.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final Product? product;
  final String? productId;
  final String? shopId;
  const ProductDetailsScreen({super.key, this.product, this.productId, this.shopId});

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  Product? _product;
  Product get product => _product!;

  @override
  Widget build(BuildContext context) {
    final sId = widget.product?.shopId ?? widget.shopId;
    final pId = widget.product?.id ?? widget.productId;
    if (sId == null || pId == null) {
      return const Scaffold(body: Center(child: Text('Invalid product details')));
    }

    final productAsync = ref.watch(productDetailsStreamProvider('$sId:$pId'));

    return productAsync.when(
      data: (productData) {
        final currentProduct = productData ?? _product ?? widget.product;
        if (currentProduct == null) {
          return const Scaffold(body: Center(child: Text('Product not found')));
        }
        _product = currentProduct;
        final padding = AppSizes.paddingLarge(context);

        final galleryWidget = Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ProductImageGallery(images: currentProduct.images),
        );

        final detailsWidget = _buildDetailsColumn(context);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Product Details',
              style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
            ),
          ),
          bottomNavigationBar: _buildBottomActionBar(context),
          body: SafeArea(
            child: Responsive.isTablet(context)
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: SingleChildScrollView(
                            child: galleryWidget,
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(padding),
                          child: detailsWidget,
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        galleryWidget,
                        Padding(
                          padding: EdgeInsets.all(padding),
                          child: detailsWidget,
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Failed to load product details: $error')),
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return ref.watch(shopDetailsProvider(product.shopId)).when(
      data: (shop) {
        if (shop == null) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final lat = shop.location.latitude;
                    final lng = shop.location.longitude;
                    final url = Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(shop.shopName)})');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Could not open Maps')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/chat', extra: {
                      'shopId': shop.ownerId,
                      'shopName': shop.shopName,
                      'shopLogo': shop.shopLogo,
                    });
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat with Shop'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildDetailsColumn(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final discountPercent = product.actualPrice > 0
        ? (((product.actualPrice - product.offerPrice) / product.actualPrice) * 100).toInt()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                product.category,
                style: AppTextStyles.bodyMedium(
                  context,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (product.isOutOfStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'OUT OF STOCK',
                  style: AppTextStyles.bodyMedium(context, color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        AppSpacing.verticalSm,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                product.name,
                style: AppTextStyles.titleLarge(context, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            FavoriteButton(
              itemId: product.id,
              type: FavoriteType.product,
              shopId: product.shopId,
            ),
          ],
        ),
        DynamicProductRating(
          productId: product.id,
          initialRating: product.rating,
          initialTotalReviews: product.totalReviews,
          builder: (context, rating, itemCount) {
            if (itemCount == 0) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${rating.toStringAsFixed(1)} ($itemCount ratings)',
                    style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          },
        ),
        AppSpacing.verticalMd,
        Row(
          children: [
            Text(
              '₹${product.offerPrice}',
              style: AppTextStyles.titleLarge(
                context,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSpacing.horizontalSm,
            Text(
              '₹${product.actualPrice}',
              style: AppTextStyles.bodyLarge(context, color: Colors.grey).copyWith(
                decoration: TextDecoration.lineThrough,
              ),
            ),
            if (discountPercent > 0) ...[
              AppSpacing.horizontalSm,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.discountColor,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '$discountPercent% OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        AppSpacing.verticalLg,
        const Divider(),
        AppSpacing.verticalMd,
        Text(
          'Description',
          style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.bold),
        ),
        AppSpacing.verticalSm,
        Text(
          product.description,
          style: AppTextStyles.bodyLarge(
            context,
            color: isDark ? Colors.white70 : const Color(0xFF374151),
            height: 1.5,
          ),
        ),
        AppSpacing.verticalLg,
        const Divider(),
        AppSpacing.verticalMd,
        Text(
          'Sold by',
          style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.bold),
        ),
        AppSpacing.verticalSm,
        ref.watch(shopDetailsProvider(product.shopId)).when(
          data: (shop) {
            if (shop == null) return const Text('Shop details not available');
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(AppSizes.paddingMedium(context)),
                leading: ClipOval(
                  child: shop.shopLogo.isNotEmpty 
                    ? CachedNetworkImage(
                        imageUrl: shop.shopLogo,
                        width: 48,
                        height: 48,
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
                        errorWidget: (context, url, error) => const Icon(Icons.store),
                      )
                    : const CircleAvatar(
                        radius: 24,
                        child: Icon(Icons.store),
                      ),
                ),
                title: Text(
                  shop.shopName, 
                  style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    DynamicShopRating(
                      shopId: shop.id,
                      initialRating: shop.rating,
                      initialTotalReviews: shop.totalReviews,
                      builder: (context, rating, itemCount) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${rating.toStringAsFixed(1)} ($itemCount reviews)',
                              style: AppTextStyles.bodyMedium(context, color: AppColors.textHint),
                            ),
                          ],
                        );
                      },
                    ),
                    if (shop.location.address.isNotEmpty || shop.location.city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        shop.location.address.isNotEmpty ? shop.location.address : shop.location.city,
                        style: AppTextStyles.bodyMedium(context, color: AppColors.textHint),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/shop_details', extra: shop),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox(),
        ),
        AppSpacing.verticalLg,
        _buildReviewsSection(context),
      ],
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    final reviewsAsync = ref.watch(productReviewsProvider(product.id));
    final distribution = ref.watch(productRatingDistributionProvider(product.id));
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState is Authenticated;
    final rateBtnColor = isAuthenticated
        ? Theme.of(context).colorScheme.primary
        : AppColors.textHint;

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
              onPressed: () {
                if (isAuthenticated) {
                  _handleRateProduct(context);
                } else {
                  context.push('/login');
                }
              },
              icon: Icon(Icons.rate_review_outlined, size: 18, color: rateBtnColor),
              label: Text(
                isAuthenticated ? 'Rate Product' : 'Login to Rate',
                style: TextStyle(color: rateBtnColor),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: rateBtnColor.withValues(alpha: 0.1),
                foregroundColor: rateBtnColor,
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
                      Icon(Icons.rate_review_outlined, size: 48, color: AppColors.textHint),
                      const SizedBox(height: 8),
                      Text(
                        'No reviews yet',
                        style: AppTextStyles.bodyLarge(context, color: AppColors.textHint, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Be the first to rate this product!',
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

  Future<void> _handleRateProduct(BuildContext context) async {
    final authState = ref.read(authProvider);
    if (authState is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please log in to submit a review.')),
      );
      return;
    }

    _openRatingSheet(context);
  }

  Future<void> _openRatingSheet(BuildContext context) async {
    final existingReview = await ref.read(userProductReviewProvider(product.id).future);

    if (!context.mounted) return;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => RateItemBottomSheet(
        productId: product.id,
        shopId: product.shopId,
        name: product.name,
        existingRating: existingReview?.rating,
        existingComment: existingReview?.comment,
      ),
    );

    if (submitted == true) {
      ref.invalidate(userProductReviewProvider(product.id));
    }
  }
}

class ProductImageGallery extends StatefulWidget {
  final List<String> images;
  const ProductImageGallery({super.key, required this.images});

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late final PageController _pageController;
  late final ScrollController _thumbnailScrollController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _thumbnailScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (_thumbnailScrollController.hasClients) {
      final targetOffset = index * 70.0;
      final maxScrollExtent = _thumbnailScrollController.position.maxScrollExtent;
      final minScrollExtent = _thumbnailScrollController.position.minScrollExtent;
      
      final screenWidth = MediaQuery.of(context).size.width;
      final centeredOffset = targetOffset - (screenWidth / 2) + 35.0;
      
      final double scrollPosition = centeredOffset.clamp(minScrollExtent, maxScrollExtent);
      
      _thumbnailScrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _openFullscreen(BuildContext context) {
    context.push('/product_image_fullscreen', extra: {
      'images': widget.images,
      'initialIndex': _currentIndex,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Icon(Icons.image, size: 50, color: Colors.grey),
      );
    }

    final galleryHeight = Responsive.isTablet(context) ? 400.0 : 320.0;

    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () => _openFullscreen(context),
              child: SizedBox(
                height: galleryHeight,
                width: double.infinity,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) {
                    return Hero(
                      tag: 'product_image_${widget.images[index]}',
                      child: CachedNetworkImage(
                        imageUrl: widget.images[index],
                        fit: BoxFit.contain,
                        cacheManager: AppCacheManager(),
                        placeholder: (ctx, url) {
                          final isDark = Theme.of(ctx).brightness == Brightness.dark;
                          return Shimmer.fromColors(
                            baseColor: isDark ? const Color(0xFF222C36) : Colors.grey.shade300,
                            highlightColor: isDark ? const Color(0xFF2C3742) : Colors.grey.shade100,
                            child: Container(color: isDark ? const Color(0xFF1E1E2E) : Colors.white),
                          );
                        },
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, size: 50, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: 64,
              child: ListView.builder(
                controller: _thumbnailScrollController,
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.images.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentIndex;
                  return GestureDetector(
                    onTap: () => _goToPage(index),
                    child: Builder(builder: (ctx) {
                      final cs = Theme.of(ctx).colorScheme;
                      return Container(
                      width: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : cs.outline,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                        child: CachedNetworkImage(
                          imageUrl: widget.images[index],
                          fit: BoxFit.cover,
                          cacheManager: AppCacheManager(),
                          placeholder: (pCtx, url) => Container(
                            color: Theme.of(pCtx).colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (pCtx, url, error) => Icon(
                            Icons.image,
                            size: 20,
                            color: Theme.of(pCtx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                    }),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class FullscreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullscreenImageGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullscreenImageGallery> createState() => _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends State<FullscreenImageGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return Center(
                child: Hero(
                  tag: 'product_image_${widget.images[index]}',
                  child: _FullscreenImageItem(imageUrl: widget.images[index]),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} of ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenImageItem extends StatefulWidget {
  final String imageUrl;
  const _FullscreenImageItem({required this.imageUrl});

  @override
  State<_FullscreenImageItem> createState() => _FullscreenImageItemState();
}

class _FullscreenImageItemState extends State<_FullscreenImageItem> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          fit: BoxFit.contain,
          cacheManager: AppCacheManager(),
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (context, url, error) => const Icon(
            Icons.image,
            size: 100,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
