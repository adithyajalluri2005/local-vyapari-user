import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_products_provider.dart';
import 'package:local_vyapari_user/shared/widgets/skeleton_card.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/features/favorites/presentation/widgets/favorite_button.dart';
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

const _kShimmerDark = Color(0xFF2A2A3E);
const _kShimmerDarkHL = Color(0xFF3A3A4E);

// ── Home Screen ───────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSearchTap;
  const HomeScreen({super.key, this.onSearchTap});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _offerPopupShown = false;
  final _scrollCtrl = ScrollController();
  bool _nearBottom = false;
  int _productsVisible = 10;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _scrollCtrl.position.maxScrollExtent <= 0) return;
    final nearBottom =
        _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200;
    if (!nearBottom) {
      _nearBottom = false;
      return;
    }
    if (_nearBottom) return;
    _nearBottom = true;

    final all = ref.read(nearbyProductsProvider).value ?? [];
    if (_productsVisible < all.length) {
      setState(() {
        _productsVisible = (_productsVisible + 10).clamp(0, all.length);
        _nearBottom = false; // allow re-trigger after next page loads
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final hp = Responsive.horizontalPadding(context);
    final locationAsync = ref.watch(activeBrowsingLocationProvider);
    final shopsAsync = ref.watch(nearbyShopsProvider);
    final offersAsync = ref.watch(nearbyOffersProvider);
    final shopsById = {
      for (final s in (shopsAsync.value ?? <Shop>[]))
        s.id: s
    };

    // Split offers so the spotlight and Hot Deals never show the same item.
    // If no vendor has marked an offer as featured, the spotlight is hidden.
    final featuredOffersAsync = offersAsync.whenData(
      (offers) => offers.where((o) => o.isFeatured).toList(),
    );
    final dealsOffersAsync = offersAsync.whenData(
      (offers) => offers.where((o) => !o.isFeatured).toList(),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationName = locationAsync.whenOrNull(data: (l) => l?.name) ?? '';

    ref.listen(activeBrowsingLocationProvider, (previous, next) {
      if (previous?.value != next.value) {
        ref.invalidate(nearbyShopsProvider);
        ref.invalidate(nearbyProductsProvider);
        ref.invalidate(nearbyOffersProvider);
        setState(() { _productsVisible = 10; _nearBottom = false; });
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
            setState(() { _productsVisible = 10; _nearBottom = false; });
          },
          color: Colors.white,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
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
                    const SizedBox(height: 12),

                    // Featured spotlight
                    FadeInSlide(
                      duration: const Duration(milliseconds: 400),
                      child: _FeaturedSpotlightSection(
                        offersAsync: featuredOffersAsync,
                        shopsById: shopsById,
                        userLatitude: locationAsync.value?.latitude,
                        userLongitude: locationAsync.value?.longitude,
                        hp: hp,
                        isDark: isDark,
                        onOfferTap: (offer) =>
                            _navigateToShopForOffer(context, offer),
                      ),
                    ),

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
                              trailing: SeeAllChip(onTap: () => context.push('/all_offers')),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _OfferBannerList(
                            offersAsync: dealsOffersAsync,
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
                            SectionHeader(title: 'For You'),
                            const SizedBox(height: 12),
                            _ProductsGrid(isDark: isDark, visibleCount: _productsVisible),
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
                color: Colors.white,
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
              'You\'ll be notified when shops launch new offers nearby.',
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
            Icon(
              Icons.location_on_rounded,
              color: textColor,
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
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: textColor,
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

// Featured spotlight

class _FeaturedSpotlightSection extends StatelessWidget {
  final AsyncValue<List<Offer>> offersAsync;
  final Map<String, Shop> shopsById;
  final double? userLatitude;
  final double? userLongitude;
  final double hp;
  final bool isDark;
  final void Function(Offer) onOfferTap;

  const _FeaturedSpotlightSection({
    required this.offersAsync,
    required this.shopsById,
    required this.userLatitude,
    required this.userLongitude,
    required this.hp,
    required this.isDark,
    required this.onOfferTap,
  });

  @override
  Widget build(BuildContext context) {
    return offersAsync.when(
      skipLoadingOnReload: false,
      data: (offers) {
        if (offers.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.fromLTRB(hp, 0, hp, 20),
          child: _HeroSpotlightCard(
            offers: offers,
            shopsById: shopsById,
            userLatitude: userLatitude,
            userLongitude: userLongitude,
            onOfferTap: onOfferTap,
          ),
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.fromLTRB(hp, 0, hp, 20),
        child: Shimmer.fromColors(
          baseColor: isDark ? _kShimmerDark : Colors.grey.shade300,
          highlightColor: isDark ? _kShimmerDarkHL : Colors.grey.shade100,
          child: Container(
            height: 204,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _HeroSpotlightCard extends StatefulWidget {
  final List<Offer> offers;
  final Map<String, Shop> shopsById;
  final double? userLatitude;
  final double? userLongitude;
  final void Function(Offer) onOfferTap;

  const _HeroSpotlightCard({
    required this.offers,
    required this.shopsById,
    required this.userLatitude,
    required this.userLongitude,
    required this.onOfferTap,
  });

  @override
  State<_HeroSpotlightCard> createState() => _HeroSpotlightCardState();
}

class _HeroSpotlightCardState extends State<_HeroSpotlightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _index = 0;

  // Gradient pairs: [start, end] — each maps to a unique card palette
  static const _gradients = [
    [Color(0xFF7C3AED), Color(0xFF4338CA)], // violet → indigo
    [Color(0xFFDC2626), Color(0xFFC2410C)], // crimson → orange
    [Color(0xFF0369A1), Color(0xFF0E7490)], // sky → cyan
    [Color(0xFF065F46), Color(0xFF0F766E)], // emerald → teal
    [Color(0xFF92400E), Color(0xFFB45309)], // amber → warm
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..addStatusListener(_onProgress);
    _start();
  }

  void _onProgress(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _index = (_index + 1) % widget.offers.length);
    _start();
  }

  void _start() {
    _ctrl.reset();
    if (widget.offers.length > 1) _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _HeroSpotlightCard old) {
    super.didUpdateWidget(old);
    if (_index >= widget.offers.length) _index = 0;
    if (old.offers.length != widget.offers.length) _start();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offers[_index];
    final shop = widget.shopsById[offer.shopId];
    final shopName = shop?.shopName.isNotEmpty == true
        ? shop!.shopName
        : offer.shopName.isNotEmpty
            ? offer.shopName
            : offer.title;
    final logoUrl = shop?.shopLogo ?? '';
    final rating = shop?.rating;
    final distance = _distanceLabel(shop, widget.userLatitude, widget.userLongitude);
    final discount = offer.discountPercentage.toInt();
    final colors = _gradients[_index % _gradients.length];

    return ScaleOnTap(
      onTap: () => widget.onOfferTap(offer),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Container(
          key: ValueKey('hero-$_index-${offer.id}'),
          height: 204,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors[0], colors[1]],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: colors[0].withValues(alpha: 0.36),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Decorative background circles
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                right: 24,
                bottom: -36,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: FEATURED tag + rating / distance metas
                    Row(
                      children: [
                        const _HeroTag(),
                        const Spacer(),
                        if (rating != null && rating > 0)
                          _HeroMeta(icon: Icons.star_rounded, label: rating.toStringAsFixed(1)),
                        if (rating != null && rating > 0 && distance != null)
                          const SizedBox(width: 10),
                        if (distance != null)
                          _HeroMeta(icon: Icons.place_rounded, label: distance),
                      ],
                    ),
                    const Spacer(),
                    // Bottom content: badge + name + logo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HeroBadge(discount: discount, fallback: offer.title),
                              const SizedBox(height: 10),
                              Text(
                                shopName,
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (discount > 0 && offer.title.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  offer.title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        _HeroLogo(logoUrl: logoUrl, name: shopName),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Story-style progress bars
                    _StoryProgressBars(
                      total: widget.offers.length,
                      current: _index,
                      controller: _ctrl,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _distanceLabel(Shop? shop, double? userLat, double? userLng) {
  if (shop == null || userLat == null || userLng == null) return null;
  final meters = Geolocator.distanceBetween(
    userLat, userLng,
    shop.location.latitude,
    shop.location.longitude,
  );
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

class _StoryProgressBars extends StatelessWidget {
  final int total;
  final int current;
  final AnimationController controller;

  const _StoryProgressBars({
    required this.total,
    required this.current,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        children: List.generate(total, (i) {
          final double value;
          if (i < current) {
            value = 1.0;
          } else if (i == current) {
            value = controller.value;
          } else {
            value = 0.0;
          }
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.white.withValues(alpha: 0.28),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 2.5,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'FEATURED',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white70),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final int discount;
  final String fallback;

  const _HeroBadge({required this.discount, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final text = discount > 0
        ? '$discount% OFF'
        : fallback.isNotEmpty
            ? fallback
            : 'DEAL';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _HeroLogo extends StatelessWidget {
  final String logoUrl;
  final String name;

  const _HeroLogo({required this.logoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              cacheManager: AppCacheManager(),
              errorWidget: (_, _, _) => _HeroInitial(initial: initial),
            )
          : _HeroInitial(initial: initial),
    );
  }
}

class _HeroInitial extends StatelessWidget {
  final String initial;

  const _HeroInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
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
            return _EmptySection(
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
              baseColor: isDark ? _kShimmerDark : Colors.grey.shade300,
              highlightColor: isDark ? _kShimmerDarkHL : Colors.grey.shade100,
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
        error: (_, _) => _EmptySection(
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

enum _ShopFilter { all, openNow }

class _ShopsList extends StatefulWidget {
  final AsyncValue<List<Shop>> shopsAsync;
  const _ShopsList({required this.shopsAsync});

  @override
  State<_ShopsList> createState() => _ShopsListState();
}

class _ShopsListState extends State<_ShopsList> {
  _ShopFilter _filter = _ShopFilter.all;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columns = Responsive.shopGridColumns(context);

    return widget.shopsAsync.when(
      skipLoadingOnReload: false,
      data: (allShops) {
        // Apply selected filter
        List<Shop> filtered = allShops;
        if (_filter == _ShopFilter.openNow) {
          filtered = allShops.where((s) => s.isOpen).toList();
        }

        final displayShops = filtered.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filter chips ────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _HomeFilterChip(
                    label: 'All',
                    active: _filter == _ShopFilter.all,
                    onTap: () => setState(() => _filter = _ShopFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _HomeFilterChip(
                    label: 'Open Now',
                    icon: Icons.circle,
                    active: _filter == _ShopFilter.openNow,
                    onTap: () => setState(() => _filter = _ShopFilter.openNow),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Shop list / empty ───────────────────────────────
            if (displayShops.isEmpty)
              _EmptySection(
                icon: _filter == _ShopFilter.openNow
                    ? Icons.store_mall_directory_outlined
                    : Icons.storefront_outlined,
                message: _filter == _ShopFilter.openNow
                    ? 'No shops open right now'
                    : 'No shops found nearby',
              )
            else if (columns >= 2)
              GridView.builder(
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
              )
            else
              Column(
                children: displayShops.asMap().entries.map((e) {
                  return FadeInSlide(
                    delay: Duration(milliseconds: 50 * e.key),
                    child: ShopCard(
                      shop: e.value,
                      onTap: () => context.push('/shop_details', extra: e.value),
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
      loading: () => Column(
        children: List.generate(
          3,
          (_) => Shimmer.fromColors(
            baseColor: isDark ? _kShimmerDark : Colors.grey.shade300,
            highlightColor: isDark ? _kShimmerDarkHL : Colors.grey.shade100,
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
      error: (_, _) => _EmptySection(
        icon: Icons.error_outline,
        message: 'Could not load shops',
      ),
    );
  }
}

class _HomeFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _HomeFilterChip({
    required this.label,
    this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : isDark
                  ? AppColors.darkElevated
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: icon == Icons.circle ? 7 : 12,
                color: active
                    ? Colors.white
                    : icon == Icons.circle
                        ? AppColors.accent
                        : AppColors.warning,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Products grid ─────────────────────────────────────────────────────────────

class _ProductsGrid extends ConsumerWidget {
  final bool isDark;
  final int visibleCount;
  const _ProductsGrid({required this.isDark, required this.visibleCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(nearbyProductsProvider);
    final cols = Responsive.productGridColumns(context);

    return productsAsync.when(
      skipLoadingOnReload: false,
      data: (products) {
        if (products.isEmpty) {
          return _EmptySection(
            icon: Icons.inventory_2_outlined,
            message: 'No products found nearby',
          );
        }
        final visible = products.take(visibleCount).toList();
        final hasMore = products.length > visibleCount;
        return Column(
          children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.70,
          ),
          itemCount: visible.length,
          itemBuilder: (ctx, i) {
            final p = visible[i];
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
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: FavoriteButton(
                                  itemId: p.id,
                                  type: FavoriteType.product,
                                  shopId: p.shopId,
                                  size: 15,
                                  color: Colors.white,
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  if (p.category.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      p.category,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: AppColors.textHint,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
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
                                          color: isDark ? Colors.white : AppColors.primary,
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
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SkeletonProductGrid(
              crossAxisCount: cols,
              aspectRatio: 0.70,
              spacing: 10,
              rowCount: 1,
            ),
          ),
        ],
      );
      },
      loading: () => SkeletonProductGrid(
        crossAxisCount: cols,
        aspectRatio: 0.70,
        spacing: 10,
      ),
      error: (_, _) => _EmptySection(
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
