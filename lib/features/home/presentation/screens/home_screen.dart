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
import 'package:local_vyapari_user/features/home/presentation/widgets/home_sliver_app_bar.dart';
import 'package:local_vyapari_user/features/home/presentation/widgets/featured_spotlight_section.dart';
import 'package:local_vyapari_user/features/home/presentation/widgets/offer_banner_list.dart';
import 'package:local_vyapari_user/features/home/presentation/widgets/offer_popup_sheet.dart';
import 'package:local_vyapari_user/features/home/presentation/widgets/home_shops_list.dart';
import 'package:local_vyapari_user/features/home/presentation/widgets/home_products_grid.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/primary_button.dart';
import 'package:local_vyapari_user/shared/widgets/section_header.dart';

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
        _nearBottom = false;
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

    final featuredOffersAsync = offersAsync.whenData(
      (offers) => offers.where((o) => o.isFeatured).toList(),
    );
    final dealsOffersAsync = offersAsync.whenData(
      (offers) {
        if (offers.length < 4) {
          return offers;
        }
        return offers.where((o) => !o.isFeatured).toList();
      },
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

    ref.listen(nearbyOffersProvider, (_, next) {
      if (!_offerPopupShown) {
        next.whenData((offers) {
          if (offers.isNotEmpty && mounted) {
            _offerPopupShown = true;
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                _showOfferPopup(context, offers.first);
              }
            });
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
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
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              HomeSliverAppBar(
                locationName: locationName,
                locationLoading: locationAsync.isLoading,
                isDark: isDark,
                onLocationTap: () => context.push('/location_search'),
                onNotificationTap: () => _showNotifications(context),
                onSearchTap: widget.onSearchTap,
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: 90 + MediaQuery.of(context).padding.bottom,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),

                          FeaturedSpotlightSection(
                            offersAsync: featuredOffersAsync,
                            shopsById: shopsById,
                            userLatitude: locationAsync.value?.latitude,
                            userLongitude: locationAsync.value?.longitude,
                            hp: hp,
                            isDark: isDark,
                            onOfferTap: (offer) =>
                                _navigateToShopForOffer(context, offer),
                          ),

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
                                OfferBannerList(
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
                                  ShopsList(shopsAsync: shopsAsync),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),

                          FadeInSlide(
                            duration: const Duration(milliseconds: 450),
                            delay: const Duration(milliseconds: 280),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: hp),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SectionHeader(title: 'For You'),
                                  const SizedBox(height: 4),
                                  ProductsGrid(isDark: isDark, visibleCount: _productsVisible),
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
            ],
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
      builder: (_) => OfferPopupSheet(
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
