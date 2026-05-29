import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/features/favorites/providers/favorites_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_products_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_product_rating.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/category_chip.dart';
import 'package:local_vyapari_user/shared/widgets/hero_mini_stat.dart';
import 'package:local_vyapari_user/shared/widgets/offer_card.dart';
import 'package:local_vyapari_user/shared/widgets/primary_button.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/widgets/section_header.dart';
import 'package:local_vyapari_user/shared/widgets/shop_card.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSearchTap;
  const HomeScreen({super.key, this.onSearchTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'All';

  static const _categories = [
    'All', 'Grocery', 'Pharmacy', 'Electronics', 'Clothing', 'Food', 'Beauty', 'Books',
  ];

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final hp = Responsive.horizontalPadding(context);
    final locationAsync = ref.watch(activeBrowsingLocationProvider);
    final shopsAsync = ref.watch(nearbyShopsProvider);
    final offersAsync = ref.watch(nearbyOffersProvider);
    final authState = ref.watch(authProvider);
    final userName = authState is Authenticated
        ? (authState.user.displayName ?? authState.user.email ?? 'there')
        : 'there';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(activeBrowsingLocationProvider, (previous, next) {
      if (previous?.value != next.value) {
        ref.invalidate(nearbyShopsProvider);
        ref.invalidate(nearbyProductsProvider);
        ref.invalidate(nearbyOffersProvider);
      }
    });

    final shopCount = shopsAsync.whenOrNull(data: (s) => s.length) ?? 0;
    final offerCount = offersAsync.whenOrNull(data: (o) => o.length) ?? 0;
    final openCount = shopsAsync.whenOrNull(data: (s) => s.where((sh) => sh.isOpen).length) ?? 0;
    final locationName = locationAsync.whenOrNull(data: (l) => l?.name) ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      appBar: _GreetingAppBar(
        greeting: _greeting(),
        userName: userName,
        onSearchTap: widget.onSearchTap,
        isDark: isDark,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(nearbyShopsProvider);
            ref.invalidate(nearbyOffersProvider);
            ref.invalidate(nearbyProductsProvider);
          },
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: 90 + MediaQuery.of(context).padding.bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // ── Hero card ─────────────────────────────
                      FadeInSlide(
                        duration: const Duration(milliseconds: 550),
                        slideOffset: 24,
                        child: _HeroCard(
                          locationName: locationName,
                          shopCount: shopCount,
                          offerCount: offerCount,
                          openCount: openCount,
                          onExploreTap: () => context.push('/radar'),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Stats row ─────────────────────────────
                      FadeInSlide(
                        duration: const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 80),
                        child: _StatsRow(
                          shopCount: shopCount,
                          offerCount: offerCount,
                          openCount: openCount,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Featured offers ───────────────────────
                      FadeInSlide(
                        duration: const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              title: 'Featured Offers',
                              trailing: SeeAllChip(onTap: () {}),
                            ),
                            const SizedBox(height: 12),
                            _OffersHScroll(offersAsync: offersAsync, isDark: isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Nearby shops ──────────────────────────
                      FadeInSlide(
                        duration: const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 260),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              title: 'Shops Near You',
                              trailing: SeeAllChip(onTap: () => context.push('/radar')),
                            ),
                            const SizedBox(height: 12),
                            _ShopsList(shopsAsync: shopsAsync),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Category filter ───────────────────────
                      const SectionHeader(title: 'Browse by Category'),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: CategoryChip(
                                label: cat,
                                selected: _selectedCategory == cat,
                                onTap: () => setState(() => _selectedCategory = cat),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Products grid ─────────────────────────
                      FadeInSlide(
                        duration: const Duration(milliseconds: 450),
                        delay: const Duration(milliseconds: 320),
                        child: _ProductsGrid(isDark: isDark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── App bar ──────────────────────────────────────────────────────────────────

class _GreetingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String greeting;
  final String userName;
  final VoidCallback? onSearchTap;
  final bool isDark;

  const _GreetingAppBar({
    required this.greeting,
    required this.userName,
    required this.onSearchTap,
    required this.isDark,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            greeting,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textHint,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            _displayName(userName),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: onSearchTap,
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => _showNotifications(context),
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  String _displayName(String raw) {
    if (raw.contains('@')) return raw.split('@').first;
    return raw;
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 26,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'All caught up',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              "You'll be notified when shops launch new offers nearby.",
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Got it', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String locationName;
  final int shopCount;
  final int offerCount;
  final int openCount;
  final VoidCallback onExploreTap;
  final bool isDark;

  const _HeroCard({
    required this.locationName,
    required this.shopCount,
    required this.offerCount,
    required this.openCount,
    required this.onExploreTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shops Near You',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 13, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                locationName.isNotEmpty ? locationName : 'Set your location',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Mini stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              HeroMiniStat(
                icon: Icons.storefront_rounded,
                label: 'Shops Nearby',
                value: '$shopCount',
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              HeroMiniStat(
                icon: Icons.local_offer_rounded,
                label: 'Active Offers',
                value: '$offerCount',
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              HeroMiniStat(
                icon: Icons.check_circle_outline_rounded,
                label: 'Open Now',
                value: '$openCount',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onExploreTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: const Text('Explore Shops'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row (horizontal scroll on phone, grid on tablet) ───────────────────

class _StatsRow extends StatelessWidget {
  final int shopCount;
  final int offerCount;
  final int openCount;
  final bool isDark;

  const _StatsRow({
    required this.shopCount,
    required this.offerCount,
    required this.openCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatTileData('Nearby Shops', '$shopCount', AppColors.info, Icons.storefront_outlined),
      _StatTileData('Live Offers', '$offerCount', AppColors.warning, Icons.local_offer_outlined),
      _StatTileData('Open Now', '$openCount', AppColors.accent, Icons.check_circle_outline),
      _StatTileData('Saved', '—', AppColors.primary, Icons.favorite_outline_rounded),
    ];

    if (Responsive.useStatsGrid(context)) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.4,
        children: tiles.map((t) => _StatTile(data: t, isDark: isDark)).toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tiles.map((t) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: SizedBox(
            width: 116,
            child: _StatTile(data: t, isDark: isDark),
          ),
        )).toList(),
      ),
    );
  }
}

class _StatTileData {
  final String label;
  final String value;
  final Color accentColor;
  final IconData icon;
  const _StatTileData(this.label, this.value, this.accentColor, this.icon);
}

class _StatTile extends StatelessWidget {
  final _StatTileData data;
  final bool isDark;
  const _StatTile({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final shadow = Colors.black.withValues(alpha: isDark ? 0.2 : 0.055);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
          left: BorderSide(color: data.accentColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(color: shadow, blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// ── Offers horizontal scroll ──────────────────────────────────────────────────

class _OffersHScroll extends StatelessWidget {
  final AsyncValue offersAsync;
  final bool isDark;
  const _OffersHScroll({required this.offersAsync, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: offersAsync.when(
        skipLoadingOnReload: false,
        data: (offers) {
          if (offers.isEmpty) {
            return const _EmptySection(
              icon: Icons.local_offer_outlined,
              message: 'No active offers nearby',
            );
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: offers.length,
            itemBuilder: (ctx, i) => Padding(
              padding: EdgeInsets.only(right: 12, left: i == 0 ? 0 : 0),
              child: SizedBox(
                width: 220,
                child: FadeInSlide(
                  delay: Duration(milliseconds: 50 * i),
                  child: OfferCard(
                    offer: offers[i],
                    onTap: () {},
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => _ShimmerHList(height: 280, itemWidth: 220, isDark: isDark),
        error: (_, __) => const _EmptySection(
          icon: Icons.error_outline,
          message: 'Could not load offers',
        ),
      ),
    );
  }
}

// ── Shops list ────────────────────────────────────────────────────────────────

class _ShopsList extends StatelessWidget {
  final AsyncValue<List<Shop>> shopsAsync;
  const _ShopsList({required this.shopsAsync});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columns = Responsive.shopGridColumns(context);

    return shopsAsync.when(
      skipLoadingOnReload: false,
      data: (shops) {
        if (shops.isEmpty) {
          return const _EmptySection(
            icon: Icons.storefront_outlined,
            message: 'No shops found nearby',
          );
        }
        final displayShops = shops.take(6).toList();

        if (columns >= 2) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.5,
            ),
            itemCount: displayShops.length,
            itemBuilder: (ctx, i) => FadeInSlide(
              delay: Duration(milliseconds: 50 * i),
              child: ShopCard(
                shop: displayShops[i],
                onTap: () => context.push('/shop_details', extra: displayShops[i]),
              ),
            ),
          );
        }

        return Column(
          children: displayShops.asMap().entries.map((e) => FadeInSlide(
            delay: Duration(milliseconds: 50 * e.key),
            child: ShopCard(
              shop: e.value,
              onTap: () => context.push('/shop_details', extra: e.value),
            ),
          )).toList(),
        );
      },
      loading: () => Column(
        children: List.generate(
          3,
          (i) => _ShimmerListItem(isDark: isDark),
        ),
      ),
      error: (_, __) => const _EmptySection(
        icon: Icons.error_outline,
        message: 'Could not load shops',
      ),
    );
  }
}

// ── Products grid ─────────────────────────────────────────────────────────────

class _ProductsGrid extends ConsumerWidget {
  final bool isDark;
  const _ProductsGrid({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(nearbyProductsProvider);
    final cols = Responsive.productGridColumns(context);

    return productsAsync.when(
      skipLoadingOnReload: false,
      data: (products) {
        if (products.isEmpty) {
          return const _EmptySection(
            icon: Icons.inventory_2_outlined,
            message: 'No products found nearby',
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.70,
          ),
          itemCount: products.length,
          itemBuilder: (ctx, i) {
            final p = products[i];
            final hasDiscount = p.actualPrice > p.offerPrice;
            final discPct = hasDiscount
                ? ((1 - p.offerPrice / p.actualPrice) * 100).toInt()
                : 0;
            final bg = isDark ? AppColors.darkSurface : AppColors.surface;
            final border = isDark ? Colors.white10 : AppColors.border.withValues(alpha: 0.8);
            final shadow = Colors.black.withValues(alpha: isDark ? 0.2 : 0.055);

            return FadeInSlide(
              delay: Duration(milliseconds: 50 * i),
              child: ScaleOnTap(
                onTap: () => context.push('/product_details', extra: p),
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: border, width: 0.7),
                    boxShadow: [
                      BoxShadow(color: shadow, blurRadius: 14, offset: const Offset(0, 4)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 1.1,
                            child: p.images.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: p.images.first,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: AppColors.surfaceElevated,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: AppColors.surfaceElevated,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: AppColors.surfaceElevated,
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                          ),
                          if (hasDiscount)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  '$discPct% off',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                p.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DynamicProductRating(
                                    productId: p.id,
                                    initialRating: p.rating,
                                    initialTotalReviews: p.totalReviews,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      color: AppColors.textHint,
                                    ),
                                    iconSize: 11,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '₹${p.offerPrice}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      if (hasDiscount) ...[
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '₹${p.actualPrice}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: AppColors.textHint,
                                              decoration: TextDecoration.lineThrough,
                                              decorationColor: AppColors.textHint,
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
              ),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _EmptySection(
        icon: Icons.error_outline,
        message: 'Could not load products',
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.textHint),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerHList extends StatelessWidget {
  final double height;
  final double itemWidth;
  final bool isDark;
  const _ShimmerHList({required this.height, required this.itemWidth, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Shimmer.fromColors(
          baseColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade300,
          highlightColor: isDark ? const Color(0xFF3A3A4E) : Colors.grey.shade100,
          child: Container(
            width: itemWidth,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerListItem extends StatelessWidget {
  final bool isDark;
  const _ShimmerListItem({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade300,
      highlightColor: isDark ? const Color(0xFF3A3A4E) : Colors.grey.shade100,
      child: Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}
