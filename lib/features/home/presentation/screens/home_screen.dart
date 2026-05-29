import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
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
      if (previous?.value != next.value) {
        ref.invalidate(nearbyShopsProvider);
        ref.invalidate(nearbyProductsProvider);
        ref.invalidate(nearbyOffersProvider);
      }
    });

    final hp = AppSizes.paddingMedium(context);

    return Scaffold(
      appBar: _HomeAppBar(locationAsync: locationAsync),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search bar ────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(hp, 12, hp, 4),
                child: GestureDetector(
                  onTap: onSearchTap,
                  child: AbsorbPointer(
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: AppTheme.inkFaint, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Search products, shops…',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Sections ──────────────────────────────────────────
              _SectionHeader(title: 'Trending offers', padding: hp),
              _OffersSection(screenPadding: hp),

              _SectionHeader(
                title: 'Shops near you',
                padding: hp,
                onTap: () => context.push('/radar'),
              ),
              _ShopsSection(screenPadding: hp),

              _SectionHeader(title: 'Picked for you', padding: hp),
              _ProductsSection(screenPadding: hp),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar
// ─────────────────────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AsyncValue locationAsync;
  const _HomeAppBar({required this.locationAsync});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leadingWidth: 52,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.storefront_rounded,
            color: AppTheme.primaryColor,
            size: 26,
          ),
        ),
      ),
      title: GestureDetector(
        onTap: () => context.push('/location_search'),
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded, color: AppTheme.primaryColor, size: 17),
            const SizedBox(width: 5),
            Flexible(
              child: locationAsync.when(
                data: (loc) => Text(
                  loc != null ? loc.name : 'Set location',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                loading: () => Text(
                  'Locating…',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: AppTheme.inkMuted,
                  ),
                ),
                error: (_, __) => Text(
                  'Location unavailable',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppTheme.inkMuted),
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: AppTheme.inkMuted),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notifications',
          onPressed: () => _showNotificationsSheet(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 28, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 14),
            Text(
              'All caught up',
              style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'You\'ll hear from us when shops nearby launch new offers.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: AppTheme.inkMuted, height: 1.5),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final double padding;
  final VoidCallback? onTap;
  const _SectionHeader({required this.title, required this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 22, padding, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryColor),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offers section — bold coloured gradient cards
// ─────────────────────────────────────────────────────────────────────────────

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
            return _EmptyHint(icon: Icons.local_offer_outlined, message: 'No active offers nearby');
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: screenPadding),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              final isHighDiscount = offer.discountPercentage >= 40;

              return Container(
                width: AppSizes.offerCardWidth(context),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isHighDiscount
                        ? [const Color(0xFFBF5210), const Color(0xFFDB7020)]
                        : [const Color(0xFF2A5E18), const Color(0xFF3E8A28)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Huge discount number
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${offer.discountPercentage.toInt()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 54,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 0.9,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5, left: 3),
                          child: Text(
                            '%\nOFF',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 1.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      offer.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (offer.shopName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.storefront_outlined, size: 11, color: Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              offer.shopName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
        loading: () => _buildShimmer(
          height: AppSizes.offerCardHeight(context),
          width: AppSizes.offerCardWidth(context),
          padding: screenPadding,
          context: context,
        ),
        error: (_, __) => _EmptyHint(icon: Icons.error_outline, message: 'Couldn\'t load offers'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shops section — shadow cards with image + overlaid rating
// ─────────────────────────────────────────────────────────────────────────────

class _ShopsSection extends ConsumerWidget {
  final double screenPadding;
  const _ShopsSection({required this.screenPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(nearbyShopsProvider);
    final cardWidth = AppSizes.shopCardWidth(context);

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
              return GestureDetector(
                onTap: () => context.push('/shop_details', extra: shop),
                child: Container(
                  width: cardWidth,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          AppNetworkImage(
                            url: shop.shopLogo,
                            width: cardWidth,
                            height: AppSizes.shopImageHeight(context),
                            fallbackIcon: Icons.storefront_outlined,
                          ),
                          // Open / closed pill
                          Positioned(
                            top: 8,
                            left: 8,
                            child: _StatusPill(isOpen: shop.isOpen),
                          ),
                          // Rating badge
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: DynamicShopRating(
                              shopId: shop.id,
                              initialRating: shop.rating,
                              initialTotalReviews: shop.totalReviews,
                              builder: (_, rating, __) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.62),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                                    const SizedBox(width: 3),
                                    Text(
                                      rating > 0 ? rating.toStringAsFixed(1) : 'New',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.shopName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shop.location.city.isNotEmpty ? shop.location.city : 'Nearby',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppTheme.inkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => _buildShimmer(
          height: AppSizes.shopCardHeight(context),
          width: AppSizes.shopCardWidth(context),
          padding: screenPadding,
          context: context,
        ),
        error: (e, s) {
          debugPrint('Error loading shops: $e\n$s');
          return _EmptyHint(icon: Icons.error_outline, message: 'Couldn\'t load shops');
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Products section — grid with discount badge
// ─────────────────────────────────────────────────────────────────────────────

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
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: AppSizes.productGridAspectRatio(context),
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final hasDiscount = product.actualPrice > product.offerPrice;
              final discountPct = hasDiscount
                  ? ((1 - product.offerPrice / product.actualPrice) * 100).toInt()
                  : 0;

              return GestureDetector(
                onTap: () => context.push('/product_details', extra: product),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
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
                            aspectRatio: 1.15,
                            child: AppNetworkImage(
                              url: product.images.isNotEmpty ? product.images.first : '',
                              width: double.infinity,
                            ),
                          ),
                          if (hasDiscount)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$discountPct% off',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
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
                              Text(
                                product.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DynamicProductRating(
                                    productId: product.id,
                                    initialRating: product.rating,
                                    initialTotalReviews: product.totalReviews,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppTheme.inkMuted,
                                    ),
                                    iconSize: 11,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '₹${product.offerPrice}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      if (hasDiscount) ...[
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '₹${product.actualPrice}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              color: AppTheme.inkFaint,
                                              decoration: TextDecoration.lineThrough,
                                              decorationColor: AppTheme.inkFaint,
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
              );
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
        error: (_, __) => _EmptyHint(icon: Icons.error_outline, message: 'Couldn\'t load products'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildShimmer({
  required double height,
  required double width,
  required double padding,
  required BuildContext context,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return ListView.builder(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    padding: EdgeInsets.symmetric(horizontal: padding),
    itemCount: 3,
    itemBuilder: (_, i) => Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF222C36) : const Color(0xFFECEBE6),
      highlightColor: isDark ? const Color(0xFF2C3742) : const Color(0xFFF5F4F0),
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final bool isOpen;
  const _StatusPill({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppTheme.successColor : AppTheme.errorColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.circular),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'Open' : 'Closed',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
          Icon(icon, color: AppTheme.inkFaint, size: 24),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.inkMuted),
          ),
        ],
      ),
    );
  }
}
