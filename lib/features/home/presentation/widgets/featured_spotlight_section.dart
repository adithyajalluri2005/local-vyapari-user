import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';

const _kShimmerDark = Color(0xFF2A2A3E);
const _kShimmerDarkHL = Color(0xFF3A3A4E);

class FeaturedSpotlightSection extends StatelessWidget {
  final AsyncValue<List<Offer>> offersAsync;
  final Map<String, Shop> shopsById;
  final double? userLatitude;
  final double? userLongitude;
  final double hp;
  final bool isDark;
  final void Function(Offer) onOfferTap;

  const FeaturedSpotlightSection({
    super.key,
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
          child: HeroSpotlightCard(
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
            height: AppSizes.heroSpotlightHeight(context) + 34,
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

class HeroSpotlightCard extends StatefulWidget {
  final List<Offer> offers;
  final Map<String, Shop> shopsById;
  final double? userLatitude;
  final double? userLongitude;
  final void Function(Offer) onOfferTap;

  const HeroSpotlightCard({
    super.key,
    required this.offers,
    required this.shopsById,
    required this.userLatitude,
    required this.userLongitude,
    required this.onOfferTap,
  });

  @override
  State<HeroSpotlightCard> createState() => _HeroSpotlightCardState();
}

class _HeroSpotlightCardState extends State<HeroSpotlightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _index = 0;

  static const _gradients = [
    [Color(0xFF112E51), Color(0xFF2C5E8A)],
    [Color(0xFF0B1F38), Color(0xFF1E436D)],
    [Color(0xFF16355C), Color(0xFF31639C)],
    [Color(0xFF0D233E), Color(0xFF214670)],
    [Color(0xFF1A3960), Color(0xFF386CA3)],
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
  void didUpdateWidget(covariant HeroSpotlightCard old) {
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
          height: AppSizes.heroSpotlightHeight(context),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const HeroTag(),
                        const Spacer(),
                        if (rating != null && rating > 0)
                          HeroMeta(icon: Icons.star_rounded, label: rating.toStringAsFixed(1)),
                        if (rating != null && rating > 0 && distance != null)
                          const SizedBox(width: 10),
                        if (distance != null)
                          HeroMeta(icon: Icons.place_rounded, label: distance),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HeroBadge(discount: discount, fallback: offer.title),
                              const SizedBox(height: 6),
                              Text(
                                shopName,
                                style: GoogleFonts.poppins(
                                  fontSize: Responsive.isTablet(context) ? 24.0 : (Responsive.isSmallPhone(context) ? 17.0 : 20.0),
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
                                    fontSize: 11.5,
                                    color: Colors.white70,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (offer.description.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  offer.description,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        HeroLogo(logoUrl: logoUrl, name: shopName),
                      ],
                    ),
                    const SizedBox(height: 10),
                    StoryProgressBars(
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

class StoryProgressBars extends StatelessWidget {
  final int total;
  final int current;
  final AnimationController controller;

  const StoryProgressBars({
    super.key,
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

class HeroTag extends StatelessWidget {
  const HeroTag({super.key});

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

class HeroMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const HeroMeta({super.key, required this.icon, required this.label});

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

class HeroBadge extends StatelessWidget {
  final int discount;
  final String fallback;

  const HeroBadge({super.key, required this.discount, required this.fallback});

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

class HeroLogo extends StatelessWidget {
  final String logoUrl;
  final String name;

  const HeroLogo({super.key, required this.logoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final logoSize = Responsive.isTablet(context) ? 76.0 : (Responsive.isSmallPhone(context) ? 54.0 : 64.0);
    return Container(
      width: logoSize,
      height: logoSize,
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
              errorWidget: (_, _, _) => HeroInitial(initial: initial),
            )
          : HeroInitial(initial: initial),
    );
  }
}

class HeroInitial extends StatelessWidget {
  final String initial;

  const HeroInitial({super.key, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
