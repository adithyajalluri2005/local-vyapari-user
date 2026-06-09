import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
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
  bool _showAllReviews = false;

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

        return Scaffold(
          bottomNavigationBar: _buildBottomBar(context),
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageZone(context),
                    _buildContent(context),
                  ],
                ),
              ),
              _buildFloatingButtons(context),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Failed to load product: $error')),
      ),
    );
  }

  // ── Image zone: edge-to-edge gallery + rounded card peek ──────────────────

  Widget _buildImageZone(BuildContext context) {
    final galleryHeight = Responsive.isTablet(context) ? 420.0 : 340.0;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Stack(
      children: [
        ProductImageGallery(images: product.images, height: galleryHeight),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButtons(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _FloatingIconButton(
              icon: Icons.arrow_back,
              onTap: () => context.pop(),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FavoriteButton(
                  itemId: product.id,
                  type: FavoriteType.product,
                  shopId: product.shopId,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Content card ──────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hPad = Responsive.isTablet(context) ? 28.0 : 20.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPriceRow(context),
          AppSpacing.verticalSm,
          _buildNameRow(context),
          AppSpacing.verticalXs,
          _buildRatingRow(context),
          AppSpacing.verticalSm,
          _buildBadges(context),
          AppSpacing.verticalLg,
          _buildDescriptionCard(context, isDark),
          AppSpacing.verticalLg,
          _buildShopSection(context, isDark),
          AppSpacing.verticalLg,
          _buildReviewsSection(context),
          AppSpacing.verticalXxl,
        ],
      ),
    );
  }

  Widget _buildPriceRow(BuildContext context) {
    final discountPercent = product.actualPrice > 0
        ? (((product.actualPrice - product.offerPrice) / product.actualPrice) * 100).toInt()
        : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '₹${product.offerPrice.toStringAsFixed(0)}',
          style: AppTextStyles.titleLarge(
            context,
            color: isDark ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
          ).copyWith(fontSize: Responsive.isTablet(context) ? 32 : 28),
        ),
        if (product.actualPrice > product.offerPrice) ...[
          AppSpacing.horizontalSm,
          Text(
            '₹${product.actualPrice.toStringAsFixed(0)}',
            style: AppTextStyles.bodyLarge(context, color: AppColors.textHint).copyWith(
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
        if (discountPercent > 0) ...[
          AppSpacing.horizontalSm,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.discountColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '$discountPercent% OFF',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNameRow(BuildContext context) {
    return Text(
      product.name,
      style: AppTextStyles.titleLarge(context, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildRatingRow(BuildContext context) {
    return DynamicProductRating(
      productId: product.id,
      initialRating: product.rating,
      initialTotalReviews: product.totalReviews,
      builder: (context, rating, itemCount) {
        if (itemCount == 0) return const SizedBox();
        return Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: AppTextStyles.bodyMedium(context, fontWeight: FontWeight.w700),
            ),
            Text(
              ' · $itemCount ratings',
              style: AppTextStyles.bodyMedium(context, color: AppColors.textHint),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadges(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _Chip(
          label: product.category,
          color: Theme.of(context).colorScheme.primary,
        ),
        if (product.isOutOfStock)
          _Chip(label: 'OUT OF STOCK', color: AppColors.error),
      ],
    );
  }

  Widget _buildDescriptionCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About this product',
            style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.bold),
          ),
          AppSpacing.verticalSm,
          Text(
            product.description,
            style: AppTextStyles.bodyMedium(
              context,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sold by', style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.bold)),
        AppSpacing.verticalSm,
        ref.watch(shopDetailsProvider(product.shopId)).when(
          data: (shop) {
            if (shop == null) return const Text('Shop details not available');
            return InkWell(
              onTap: () => context.push('/shop_details', extra: shop),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevated : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: shop.shopLogo.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: shop.shopLogo,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              cacheManager: AppCacheManager(),
                              placeholder: (ctx, _) {
                                final dark = Theme.of(ctx).brightness == Brightness.dark;
                                return Shimmer.fromColors(
                                  baseColor: dark ? const Color(0xFF222C36) : Colors.grey.shade300,
                                  highlightColor: dark ? const Color(0xFF2C3742) : Colors.grey.shade100,
                                  child: Container(color: dark ? const Color(0xFF1E1E2E) : Colors.white),
                                );
                              },
                              errorWidget: (_, _, _) => _shopAvatarPlaceholder(),
                            )
                          : _shopAvatarPlaceholder(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.shopName,
                            style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          DynamicShopRating(
                            shopId: shop.id,
                            initialRating: shop.rating,
                            initialTotalReviews: shop.totalReviews,
                            builder: (context, rating, itemCount) {
                              final parts = <String>[];
                              if (itemCount > 0) {
                                parts.add('★ ${rating.toStringAsFixed(1)} · $itemCount reviews');
                              }
                              final addr = shop.location.address.isNotEmpty
                                  ? shop.location.address
                                  : shop.location.city;
                              if (addr.isNotEmpty) parts.add(addr);
                              return Text(
                                parts.join(' · '),
                                style: AppTextStyles.caption(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox(height: 68, child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const SizedBox(),
        ),
      ],
    );
  }

  Widget _shopAvatarPlaceholder() {
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      child: const Icon(Icons.store, color: AppColors.primary, size: 20),
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    final reviewsAsync = ref.watch(productReviewsProvider(product.id));
    final distribution = ref.watch(productRatingDistributionProvider(product.id));
    final isAuthenticated = ref.watch(authProvider) is Authenticated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ratings & Reviews',
              style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: isAuthenticated
                  ? () => _handleRateProduct(context)
                  : () => context.push('/login'),
              icon: const Icon(Icons.rate_review_outlined, size: 15),
              label: Text(isAuthenticated ? 'Rate' : 'Login to Rate', style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        AppSpacing.verticalSm,
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.rate_review_outlined, size: 40, color: AppColors.textHint),
                      AppSpacing.verticalSm,
                      Text(
                        'No reviews yet',
                        style: AppTextStyles.bodyMedium(context, color: AppColors.textHint, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Be the first to rate this product!',
                        style: AppTextStyles.caption(context),
                      ),
                    ],
                  ),
                ),
              );
            }

            final displayed = _showAllReviews ? reviews : reviews.take(3).toList();
            return Column(
              children: [
                ...displayed.map((r) => ReviewCard(
                  userName: r.userDisplayName,
                  rating: r.rating,
                  comment: r.comment,
                  createdAt: r.createdAt,
                )),
                if (!_showAllReviews && reviews.length > 3)
                  TextButton(
                    onPressed: () => setState(() => _showAllReviews = true),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    child: Text(
                      'See all ${reviews.length} reviews',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            );
          },
          loading: () => _buildReviewsShimmer(context),
          error: (error, _) => Center(child: Text('Failed to load reviews: $error')),
        ),
      ],
    );
  }

  // ── Bottom action bar ─────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    return ref.watch(shopDetailsProvider(product.shopId)).when(
      data: (shop) {
        if (shop == null) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
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
                    final url = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                    try {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open Maps')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Directions'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
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

  // ── Shimmer ───────────────────────────────────────────────────────────────

  Widget _buildReviewsShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF222C36) : Colors.grey.shade300;
    final hi = isDark ? const Color(0xFF2C3742) : Colors.grey.shade100;
    final block = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: Column(
        children: List.generate(2, (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: block,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 18, backgroundColor: block),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 90, height: 11, color: block),
                        const SizedBox(height: 5),
                        Container(width: 55, height: 9, color: block),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 18,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(width: double.infinity, height: 12, color: block),
              const SizedBox(height: 5),
              Container(width: 180, height: 12, color: block),
            ],
          ),
        )),
      ),
    );
  }

  // ── Rating sheet ──────────────────────────────────────────────────────────

  Future<void> _handleRateProduct(BuildContext context) async {
    if (ref.read(authProvider) is! Authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.')),
      );
      return;
    }
    _openRatingSheet(context);
  }

  Future<void> _openRatingSheet(BuildContext context) async {
    final existingReview =
        await ref.read(userProductReviewProvider(product.id).future);
    if (!context.mounted) return;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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

// ── Shared chip widget ────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption(
          context,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Floating overlay button ───────────────────────────────────────────────────

class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Image gallery — dots indicator, no thumbnail strip ───────────────────────

class ProductImageGallery extends StatefulWidget {
  final List<String> images;
  final double height;

  const ProductImageGallery({
    super.key,
    required this.images,
    required this.height,
  });

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) => setState(() => _currentIndex = index);

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
        height: widget.height,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Icon(Icons.image, size: 60, color: Colors.grey),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _openFullscreen(context),
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
                    placeholder: (ctx, _) {
                      final dark = Theme.of(ctx).brightness == Brightness.dark;
                      return Shimmer.fromColors(
                        baseColor: dark ? const Color(0xFF222C36) : Colors.grey.shade300,
                        highlightColor: dark ? const Color(0xFF2C3742) : Colors.grey.shade100,
                        child: Container(
                          color: dark ? const Color(0xFF1E1E2E) : Colors.white,
                        ),
                      );
                    },
                    errorWidget: (_, _, _) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image, size: 60, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 44,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (i) {
                  final active = i == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
