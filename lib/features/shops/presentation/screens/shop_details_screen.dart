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
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_shop_rating.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';
import 'package:local_vyapari_user/features/shops/presentation/widgets/shop_product_card.dart';
import 'package:local_vyapari_user/features/shops/presentation/widgets/shop_active_offers.dart';
import 'package:local_vyapari_user/features/shops/presentation/widgets/shop_reviews_section.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/features/offers/providers/offer_details_provider.dart';
import 'package:local_vyapari_user/shared/widgets/skeleton_card.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';

class ShopDetailsScreen extends ConsumerStatefulWidget {
  final Shop? shop;
  final String? shopId;
  final Offer? initialOffer;
  final String? initialOfferId;
  const ShopDetailsScreen({super.key, this.shop, this.shopId, this.initialOffer, this.initialOfferId});

  @override
  ConsumerState<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends ConsumerState<ShopDetailsScreen> {
  Shop? _shop;
  Shop get shop => _shop!;
  final _analyticsService = AnalyticsService();

  final _scrollCtrl = ScrollController();
  final _tabletCtrl = ScrollController();
  bool _nearBottomMobile = false;
  bool _nearBottomTablet = false;
  int _visibleCount = kProductPageSize;

  @override
  void initState() {
    super.initState();
    _shop = widget.shop;
    final shopId = widget.shop?.id ?? widget.shopId;
    if (shopId != null) {
      _analyticsService.trackShopView(widget.shop?.ownerId ?? shopId);
    }
    _scrollCtrl.addListener(_onMobileScroll);
    _tabletCtrl.addListener(_onTabletScroll);

    if (widget.initialOffer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ShopActiveOffers.showOfferSheet(
          context,
          widget.initialOffer!,
          isDark: isDark,
          shop: _shop,
        );
      });
    } else if (widget.initialOfferId != null) {
      final sId = widget.shop?.id ?? widget.shopId ?? '';
      final oId = widget.initialOfferId!;
      if (sId.isNotEmpty && oId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final offer = await ref.read(offerDetailsProvider('$sId:$oId').future);
          if (!mounted || offer == null) return;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          ShopActiveOffers.showOfferSheet(
            context,
            offer,
            isDark: isDark,
            shop: _shop,
          );
        });
      }
    }
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

    final wasNear = isTablet ? _nearBottomTablet : _nearBottomMobile;
    if (isTablet) {
      _nearBottomTablet = nearBottom;
    } else {
      _nearBottomMobile = nearBottom;
    }
    if (!nearBottom || wasNear) return;

    final shopId = widget.shop?.id ?? widget.shopId;
    if (shopId == null) return;
    final all = ref.read(shopProductsProvider(shopId)).value ?? [];
    if (_visibleCount < all.length) {
      setState(() {
        _visibleCount = (_visibleCount + kProductPageSize).clamp(0, all.length);
      });
    }
  }

  Future<void> _launchMaps(BuildContext context) async {
    final s = shop;
    _analyticsService.trackProfileClick(s.ownerId);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${s.location.latitude},${s.location.longitude}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
      }
    }
  }

  Future<void> _callShop(BuildContext context) async {
    final s = shop;
    _analyticsService.trackProfileClick(s.ownerId);
    final url = Uri.parse('tel:${s.phone}');
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
    final shopId = widget.shop?.id ?? widget.shopId;
    if (shopId == null) {
      return const Scaffold(body: Center(child: Text('Invalid shop details')));
    }

    final shopAsync = ref.watch(shopDetailsStreamProvider(shopId));

    return shopAsync.when(
      data: (shopData) {
        final currentShop = shopData ?? _shop;
        if (currentShop == null) {
          return const Scaffold(body: Center(child: Text('Shop not found')));
        }
        _shop = currentShop;
        final productsAsync = ref.watch(shopProductsProvider(currentShop.id));
        final padding = AppSizes.paddingMedium(context);

        if (Responsive.isTablet(context)) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                currentShop.shopName,
                style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
              ),
            ),
            body: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                                imageUrl: currentShop.shopLogo.isNotEmpty ? currentShop.shopLogo : (currentShop.shopBanner.isNotEmpty ? currentShop.shopBanner : 'https://via.placeholder.com/600x300'),
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
                            currentShop.description,
                            style: AppTextStyles.bodyLarge(context, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          AppSpacing.verticalMd,
                          _buildAddressAndContact(context),
                          AppSpacing.verticalLg,
                          _buildActionButtons(context),
                          AppSpacing.verticalLg,
                          ShopActiveOffers(shopId: currentShop.id, padding: padding),
                          ShopReviewsSection(shopId: currentShop.id, shopName: currentShop.shopName),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
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
                                        (ctx, i) => ShopProductCard(product: visible[i]),
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

        return Scaffold(
          body: CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              SliverAppBar(
                expandedHeight: Responsive.isSmallPhone(context) ? 200.0 : 250.0,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: CachedNetworkImage(
                    imageUrl: currentShop.shopLogo.isNotEmpty ? currentShop.shopLogo : (currentShop.shopBanner.isNotEmpty ? currentShop.shopBanner : 'https://via.placeholder.com/600x300'),
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
                        currentShop.description,
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
              SliverToBoxAdapter(
                child: ShopActiveOffers(shopId: currentShop.id, padding: padding),
              ),
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
              ..._buildMobileProductsSlivers(context, productsAsync, _visibleCount, padding),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, padding, padding, padding),
                  child: ShopReviewsSection(shopId: currentShop.id, shopName: currentShop.shopName),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Failed to load shop details: $error')),
      ),
    );
  }

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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No products available for this shop.')),
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
                (ctx, i) => ShopProductCard(product: visible[i]),
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
}
