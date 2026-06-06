import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
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
import 'package:local_vyapari_user/features/shops/providers/shop_offers_provider.dart';
import 'package:local_vyapari_user/shared/widgets/skeleton_card.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Scroll controllers: mobile uses CustomScrollView, tablet uses the products CustomScrollView.
  final _scrollCtrl = ScrollController();
  final _tabletCtrl = ScrollController();
  bool _nearBottomMobile = false;
  bool _nearBottomTablet = false;
  int _visibleCount = kProductPageSize;

  @override
  void initState() {
    super.initState();
    _shop = widget.shop;
    _analyticsService.trackShopView(shop.ownerId);
    _scrollCtrl.addListener(_onMobileScroll);
    _tabletCtrl.addListener(_onTabletScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _tabletCtrl.dispose();
    super.dispose();
  }

  void _onMobileScroll() => _maybeLoadMore(_scrollCtrl, isTablet: false);
  void _onTabletScroll() => _maybeLoadMore(_tabletCtrl, isTablet: true);

  void _maybeLoadMore(ScrollController ctrl, {required bool isTablet}) {
    if (!ctrl.hasClients || ctrl.position.maxScrollExtent <= 0) return;
    final nearBottom = ctrl.position.pixels >= ctrl.position.maxScrollExtent - 200;

    // Use edge-crossing detection so we trigger once per crossing, not every frame.
    final wasNear = isTablet ? _nearBottomTablet : _nearBottomMobile;
    if (isTablet) {
      _nearBottomTablet = nearBottom;
    } else {
      _nearBottomMobile = nearBottom;
    }
    if (!nearBottom || wasNear) return;

    final all = ref.read(shopProductsProvider(shop.id)).value ?? [];
    if (_visibleCount < all.length) {
      setState(() {
        _visibleCount = (_visibleCount + kProductPageSize).clamp(0, all.length);
      });
    }
  }

  Future<void> _launchMaps(BuildContext context) async {
    _analyticsService.trackProfileClick(shop.ownerId);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${shop.location.latitude},${shop.location.longitude}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
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
                            cacheManager: AppCacheManager(),
                            placeholder: (ctx, url) {
                              final isDark = Theme.of(ctx).brightness == Brightness.dark;
                              return Shimmer.fromColors(
                                baseColor: isDark ? const Color(0xFF222C36) : Colors.grey.shade300,
                                highlightColor: isDark ? const Color(0xFF2C3742) : Colors.grey.shade100,
                                child: Container(color: isDark ? const Color(0xFF1E1E2E) : Colors.white),
                              );
                            },
                            errorWidget: (ctx, url, error) => Container(color: Theme.of(ctx).colorScheme.surfaceContainerHighest, child: const Icon(Icons.store, size: 50)),
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
                        style: AppTextStyles.bodyLarge(context, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      AppSpacing.verticalMd,
                      _buildAddressAndContact(context),
                      AppSpacing.verticalLg,
                      _buildActionButtons(context),
                      AppSpacing.verticalLg,
                      _buildOffersSection(context, padding),
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
                          final visible = products.take(_visibleCount).toList();
                          final hasMore = products.length > _visibleCount;
                          return CustomScrollView(
                            controller: _tabletCtrl,
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.all(padding),
                                sliver: SliverGrid(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: padding,
                                    mainAxisSpacing: padding,
                                    childAspectRatio: AppSizes.productGridAspectRatio(context),
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (ctx, i) => _buildProductCard(ctx, visible[i]),
                                    childCount: visible.length,
                                  ),
                                ),
                              ),
                              if (hasMore)
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
                                  sliver: SliverToBoxAdapter(
                                    child: SkeletonProductGrid(
                                      crossAxisCount: 2,
                                      aspectRatio: AppSizes.productGridAspectRatio(context),
                                      spacing: padding,
                                      rowCount: 1,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => SkeletonProductGrid(
                          crossAxisCount: 2,
                          aspectRatio: AppSizes.productGridAspectRatio(context),
                          spacing: padding,
                          padding: EdgeInsets.all(padding),
                          shrinkWrap: false,
                        ),
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
        controller: _scrollCtrl,
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: shop.shopLogo.isNotEmpty ? shop.shopLogo : (shop.shopBanner.isNotEmpty ? shop.shopBanner : 'https://via.placeholder.com/600x300'),
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
                errorWidget: (ctx, url, error) => Container(color: Theme.of(ctx).colorScheme.surfaceContainerHighest, child: const Icon(Icons.store, size: 50)),
              ),
            ),
          ),

          // Shop info, description, contact, actions
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShopTitleRow(context),
                  AppSpacing.verticalSm,
                  _buildStatusAndRatingRow(context),
                  AppSpacing.verticalMd,
                  Text(
                    shop.description,
                    style: AppTextStyles.bodyLarge(context, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  AppSpacing.verticalMd,
                  _buildAddressAndContact(context),
                  AppSpacing.verticalLg,
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),

          // Active Offers section (full width for edge-to-edge horizontal scroll)
          SliverToBoxAdapter(
            child: _buildOffersSection(context, padding),
          ),

          // Products section heading
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Products',
                    style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
                  ),
                  AppSpacing.verticalMd,
                ],
              ),
            ),
          ),

          // Products — true SliverGrid for virtualized rendering
          ..._buildMobileProductsSlivers(context, productsAsync, _visibleCount, padding),

          // Reviews + bottom padding
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, padding),
              child: _buildReviewsSection(context),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  /// Returns the list of slivers for the mobile products section.
  /// Uses [SliverGrid] so only visible cells are built (true virtualization).
  List<Widget> _buildMobileProductsSlivers(
    BuildContext context,
    AsyncValue<List<dynamic>> productsAsync,
    int visibleCount,
    double padding,
  ) {
    return productsAsync.when(
      loading: () => [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: SliverToBoxAdapter(
            child: SkeletonProductGrid(
              crossAxisCount: AppSizes.productGridColumnCount(context),
              aspectRatio: AppSizes.productGridAspectRatio(context),
              spacing: padding,
            ),
          ),
        ),
      ],
      error: (e, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Center(
              child: Text('Failed to load products',
                  style: AppTextStyles.bodyLarge(context)),
            ),
          ),
        ),
      ],
      data: (products) {
        if (products.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const Center(child: Text('No products available for this shop.')),
              ),
            ),
          ];
        }

        final visible = products.take(visibleCount).toList();
        final hasMore = products.length > visibleCount;

        return [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, 0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppSizes.productGridColumnCount(context),
                crossAxisSpacing: padding,
                mainAxisSpacing: padding,
                childAspectRatio: AppSizes.productGridAspectRatio(context),
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildProductCard(ctx, visible[i]),
                childCount: visible.length,
              ),
            ),
          ),
          if (hasMore)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              sliver: SliverToBoxAdapter(
                child: SkeletonProductGrid(
                  crossAxisCount: AppSizes.productGridColumnCount(context),
                  aspectRatio: AppSizes.productGridAspectRatio(context),
                  spacing: padding,
                  rowCount: 1,
                ),
              ),
            ),
        ];
      },
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
        timingText += ' • Closes at ${shop.closingTime!}';
      }
    } else {
      timingText = 'CLOSED';
      if (shop.openingTime != null && shop.openingTime!.isNotEmpty) {
        timingText += ' • Opens at ${shop.openingTime!}';
      }
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: shop.isOpen ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.errorColor.withValues(alpha: 0.1),
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
              Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
              AppSpacing.horizontalSm,
              Expanded(
                child: Text(
                  shop.location.address.isNotEmpty ? shop.location.address : shop.location.city,
                  style: AppTextStyles.bodyLarge(context, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        if (shop.phone.isNotEmpty) ...[
          AppSpacing.verticalSm,
          Row(
            children: [
              Icon(Icons.phone_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
              AppSpacing.horizontalSm,
              Text(
                shop.phone,
                style: AppTextStyles.bodyLarge(context, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
              child: OutlinedButton.icon(
                onPressed: () => _callShop(context),
                icon: const Icon(Icons.phone_outlined, size: 18),
                label: const Text('Call'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ),
            AppSpacing.horizontalMd,
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _launchMaps(context),
                icon: const Icon(Icons.directions_outlined, size: 18),
                label: const Text('Directions'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
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
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Chat with vendor'),
          ),
        ),
      ],
    );
  }

  static const _offerCardGradients = [
    [Color(0xFFE8445A), Color(0xFFF76F83)],
    [Color(0xFF3730A3), Color(0xFF6366F1)],
    [Color(0xFF0F766E), Color(0xFF0D9488)],
    [Color(0xFFB45309), Color(0xFFF59E0B)],
    [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
  ];

  Widget _buildOffersSection(BuildContext context, double padding) {
    final offersAsync = ref.watch(shopOffersProvider(shop.id));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return offersAsync.when(
      data: (offers) {
        if (offers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_offer_rounded, size: 13, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          'Active Offers',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      offers.length == 1 ? '1 deal' : '${offers.length} deals',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 175,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(left: padding, right: padding / 2),
                clipBehavior: Clip.none,
                itemCount: offers.length,
                itemBuilder: (ctx, i) => _buildShopOfferCard(ctx, offers[i], i, isDark),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildShopOfferCard(BuildContext context, dynamic offer, int index, bool isDark) {
    final colors = _offerCardGradients[index % _offerCardGradients.length];
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final DateTime? endDate = offer.endDate as DateTime?;
    final int? daysLeft = endDate?.difference(DateTime.now()).inDays;
    final String description = (offer.description as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: colors[0].withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Gradient top band
            Container(
              height: 78,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '${offer.discountPercentage.toInt()}%\nOFF',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.local_offer_rounded,
                    size: 36,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ],
              ),
            ),
            // Bottom content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    if (daysLeft != null)
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 10,
                            color: daysLeft <= 1 ? AppColors.error : colors[0],
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              daysLeft == 0
                                  ? 'Ends today'
                                  : daysLeft < 0
                                      ? 'Expired'
                                      : '$daysLeft days left',
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: daysLeft <= 1 ? AppColors.error : colors[0],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Limited time offer',
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).colorScheme.primary,
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
                        'Be the first to share your experience!',
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

  Future<void> _handleRateShop(BuildContext context) async {
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
    final existingReview = await ref.read(userShopReviewProvider(shop.id).future);

    if (!context.mounted) return;

    final submitted = await showModalBottomSheet<bool>(
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

    if (submitted == true) {
      ref.invalidate(userShopReviewProvider(shop.id));
    }
  }
}
