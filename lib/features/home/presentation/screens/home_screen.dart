import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_products_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_product_rating.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/primary_button.dart';
import 'package:local_vyapari_user/shared/widgets/section_header.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/widgets/shop_card.dart';
import 'package:shimmer/shimmer.dart';

// ── Home Screen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSearchTap;
  const HomeScreen({super.key, this.onSearchTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _offerPopupShown = false;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final hp = Responsive.horizontalPadding(context);
    final locationAsync = ref.watch(activeBrowsingLocationProvider);
    final shopsAsync = ref.watch(nearbyShopsProvider);
    final offersAsync = ref.watch(nearbyOffersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationName = locationAsync.whenOrNull(data: (l) => l?.name) ?? '';

    ref.listen(activeBrowsingLocationProvider, (previous, next) {
      if (previous?.value != next.value) {
        ref.invalidate(nearbyShopsProvider);
        ref.invalidate(nearbyProductsProvider);
        ref.invalidate(nearbyOffersProvider);
      }
    });

    // Show offer popup once per session when offers load
    ref.listen(nearbyOffersProvider, (_, next) {
      if (!_offerPopupShown) {
        next.whenData((offers) {
          if (offers.isNotEmpty && mounted) {
            _offerPopupShown = true;
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                // ignore: use_build_context_synchronously
                _showOfferPopup(context, offers.first);
              }
            });
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      appBar: _HomeAppBar(
        locationName: locationName,
        locationLoading: locationAsync.isLoading,
        isDark: isDark,
        onLocationTap: () => context.push('/location_search'),
        onNotificationTap: () => _showNotifications(context),
        onSearchTap: widget.onSearchTap,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ── Promo banner carousel ──────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hp),
                      child: FadeInSlide(
                        duration: const Duration(milliseconds: 500),
                        child: _PromoBannerCarousel(
                          offersAsync: offersAsync,
                          isDark: isDark,
                          onOfferTap: (offer) =>
                              _navigateToShopForOffer(context, offer),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Hot deals ──────────────────────────────────
                    FadeInSlide(
                      duration: const Duration(milliseconds: 450),
                      delay: const Duration(milliseconds: 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: hp),
                            child: SectionHeader(
                              title: 'Hot Deals',
                              trailing: SeeAllChip(onTap: () {}),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _OfferBannerList(
                            offersAsync: offersAsync,
                            hp: hp,
                            isDark: isDark,
                            onOfferTap: (offer) =>
                                _navigateToShopForOffer(context, offer),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // ── Shops near you ─────────────────────────────
                    FadeInSlide(
                      duration: const Duration(milliseconds: 450),
                      delay: const Duration(milliseconds: 220),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: hp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              title: 'Shops Near You',
                              trailing: SeeAllChip(
                                onTap: () => context.push('/radar'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ShopsList(shopsAsync: shopsAsync),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    // ── For you ────────────────────────────────────
                    FadeInSlide(
                      duration: const Duration(milliseconds: 450),
                      delay: const Duration(milliseconds: 280),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: hp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'For You'),
                            const SizedBox(height: 12),
                            _ProductsGrid(isDark: isDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToShopForOffer(BuildContext context, Offer offer) {
    final shops = ref.read(nearbyShopsProvider).value ?? [];
    final matches = shops.where((s) => s.id == offer.shopId);
    if (matches.isEmpty) return;
    context.push('/shop_details', extra: matches.first);
  }

  void _showOfferPopup(BuildContext context, Offer offer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OfferPopupSheet(
        offer: offer,
        onGrabTap: () {
          Navigator.pop(context);
          _navigateToShopForOffer(context, offer);
        },
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
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

// ── App bar ───────────────────────────────────────────────────────────────────

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String locationName;
  final bool locationLoading;
  final bool isDark;
  final VoidCallback onLocationTap;
  final VoidCallback onNotificationTap;
  final VoidCallback? onSearchTap;

  const _HomeAppBar({
    required this.locationName,
    required this.locationLoading,
    required this.isDark,
    required this.onLocationTap,
    required this.onNotificationTap,
    this.onSearchTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 56);

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: GestureDetector(
        onTap: onLocationTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Browsing near',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        locationLoading
                            ? 'Detecting location...'
                            : locationName.isNotEmpty
                                ? locationName
                                : 'Set your location',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: onNotificationTap,
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: GestureDetector(
            onTap: onSearchTap,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: isDark ? Colors.white12 : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Search shops, products & offers...',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Promo banner carousel ─────────────────────────────────────────────────────

class _PromoBannerCarousel extends StatefulWidget {
  final AsyncValue<List<Offer>> offersAsync;
  final bool isDark;
  final void Function(Offer) onOfferTap;
  const _PromoBannerCarousel({
    required this.offersAsync,
    required this.isDark,
    required this.onOfferTap,
  });

  @override
  State<_PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<_PromoBannerCarousel> {
  final _controller = PageController();
  int _currentPage = 0;
  Timer? _timer;
  bool _timerStarted = false;

  static const _gradients = [
    [Color(0xFF3D1A78), Color(0xFF6A35B8)],
    [Color(0xFF0D4F5C), Color(0xFF1A8FA8)],
    [Color(0xFF7F1D4D), Color(0xFFBE3D7A)],
    [Color(0xFF064E3B), Color(0xFF059669)],
    [Color(0xFF7C4A00), Color(0xFFD97706)],
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startTimer(int count) {
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % count;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.offersAsync.when(
      skipLoadingOnReload: false,
      data: (offers) {
        if (offers.isEmpty) return const _StaticBanner();
        final pages = offers.take(5).toList();
        if (!_timerStarted) {
          _timerStarted = true;
          Future.microtask(() => _startTimer(pages.length));
        }
        return Column(
          children: [
            SizedBox(
              height: 168,
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _BannerPage(
                  offer: pages[i],
                  gradient: _gradients[i % _gradients.length],
                  onTap: () => widget.onOfferTap(pages[i]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                );
              }),
            ),
          ],
        );
      },
      loading: () => Shimmer.fromColors(
        baseColor: widget.isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade300,
        highlightColor: widget.isDark ? const Color(0xFF3A3A4E) : Colors.grey.shade100,
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      ),
      error: (_, _) => const _StaticBanner(),
    );
  }
}

class _BannerPage extends StatelessWidget {
  final Offer offer;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _BannerPage({
    required this.offer,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final discPct = offer.discountPercentage.toInt();
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Large watermark number for visual depth
          Positioned(
            right: -6,
            bottom: -14,
            child: Text(
              '$discPct',
              style: GoogleFonts.poppins(
                fontSize: 136,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.09),
                height: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'HOT DEAL',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Big bold discount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$discPct%',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        'OFF',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  offer.title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Shop name + white CTA button
                Row(
                  children: [
                    if (offer.shopName.isNotEmpty) ...[
                      const Icon(
                        Icons.storefront_rounded,
                        size: 13,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          offer.shopName,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'Shop Now',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: gradient[0],
                          ),
                        ),
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

class _StaticBanner extends StatelessWidget {
  const _StaticBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D1A78), Color(0xFF6A35B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -18,
            child: Text(
              '★',
              style: TextStyle(
                fontSize: 160,
                color: Colors.white.withValues(alpha: 0.06),
                height: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'LOCAL VYAPARI',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Best Deals\nNear You',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Shop local, save more every day',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'Explore Shops',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3D1A78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offer banner list ─────────────────────────────────────────────────────────

class _OfferBannerList extends StatelessWidget {
  final AsyncValue<List<Offer>> offersAsync;
  final double hp;
  final bool isDark;
  final void Function(Offer) onOfferTap;

  const _OfferBannerList({
    required this.offersAsync,
    required this.hp,
    required this.isDark,
    required this.onOfferTap,
  });

  static const _cardColors = [
    [Color(0xFFE8445A), Color(0xFFF76F83)],
    [Color(0xFF3730A3), Color(0xFF6366F1)],
    [Color(0xFF0F766E), Color(0xFF0D9488)],
    [Color(0xFFB45309), Color(0xFFF59E0B)],
    [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
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
            padding: EdgeInsets.only(left: hp, right: hp / 2),
            clipBehavior: Clip.none,
            itemCount: offers.length,
            itemBuilder: (ctx, i) {
              final offer = offers[i];
              final colors = _cardColors[i % _cardColors.length];
              final cardBg = isDark ? AppColors.darkSurface : Colors.white;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FadeInSlide(
                  delay: Duration(milliseconds: 60 * i),
                  child: GestureDetector(
                    onTap: () => onOfferTap(offer),
                    child: Container(
                      width: 180,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: colors[0].withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Gradient top band with big discount
                          Container(
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
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
                                  size: 34,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ],
                            ),
                          ),
                          // White/surface bottom with title + arrow
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    offer.title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (offer.shopName.isNotEmpty)
                                        Flexible(
                                          child: Text(
                                            offer.shopName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: AppColors.textHint,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 14,
                                        color: colors[0],
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
                ),
              );
            },
          );
        },
        loading: () => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: hp),
          itemCount: 3,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Shimmer.fromColors(
              baseColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade300,
              highlightColor: isDark ? const Color(0xFF3A3A4E) : Colors.grey.shade100,
              child: Container(
                width: 180,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
        ),
        error: (_, _) => const _EmptySection(
          icon: Icons.error_outline,
          message: 'Could not load offers',
        ),
      ),
    );
  }
}

// ── Offer popup sheet ─────────────────────────────────────────────────────────

class _OfferPopupSheet extends StatelessWidget {
  final Offer offer;
  final VoidCallback onGrabTap;
  const _OfferPopupSheet({required this.offer, required this.onGrabTap});

  static const _popupGradient = [Color(0xFF6D28D9), Color(0xFF8B5CF6)];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final discPct = offer.discountPercentage.toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xxl)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Gradient header ─────────────────────────────
            Container(
              height: 62,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: _popupGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_offer_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'EXCLUSIVE DEAL',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Large centred discount
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$discPct',
                          style: GoogleFonts.poppins(
                            fontSize: 76,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF6D28D9),
                            height: 1,
                          ),
                        ),
                        TextSpan(
                          text: '%',
                          style: GoogleFonts.poppins(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF6D28D9),
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'OFF',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF8B5CF6),
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Dashed coupon divider
                  _DashedDivider(
                    color: isDark ? Colors.white12 : AppColors.border,
                  ),
                  const SizedBox(height: 18),

                  // Offer info
                  Text(
                    offer.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (offer.shopName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 13,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          offer.shopName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 26),

                  // CTA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onGrabTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Grab This Deal'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Maybe Later',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
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
}

class _DashedDivider extends StatelessWidget {
  final Color color;
  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const dashW = 6.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dashW + gap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dashW,
              height: 1.5,
              margin: const EdgeInsets.only(right: gap),
              color: color,
            ),
          ),
        );
      },
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
                onTap: () => context.push(
                  '/shop_details',
                  extra: displayShops[i],
                ),
              ),
            ),
          );
        }

        return Column(
          children: displayShops.asMap().entries.map((e) {
            return FadeInSlide(
              delay: Duration(milliseconds: 50 * e.key),
              child: ShopCard(
                shop: e.value,
                onTap: () => context.push('/shop_details', extra: e.value),
              ),
            );
          }).toList(),
        );
      },
      loading: () => Column(
        children: List.generate(
          3,
          (_) => Shimmer.fromColors(
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
          ),
        ),
      ),
      error: (_, _) => const _EmptySection(
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
            final border = isDark
                ? Colors.white10
                : AppColors.border.withValues(alpha: 0.8);
            final shadow = Colors.black.withValues(
              alpha: isDark ? 0.2 : 0.055,
            );

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
                      BoxShadow(
                        color: shadow,
                        blurRadius: 14,
                        offset: const Offset(0, 4),
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
                            aspectRatio: 1.1,
                            child: p.images.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: p.images.first,
                                    fit: BoxFit.cover,
                                    cacheManager: AppCacheManager(),
                                    placeholder: (_, _) => Container(
                                      color: AppColors.surfaceElevated,
                                    ),
                                    errorWidget: (_, _, _) => Container(
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
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
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
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              decorationColor:
                                                  AppColors.textHint,
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
      error: (_, _) => const _EmptySection(
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
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
