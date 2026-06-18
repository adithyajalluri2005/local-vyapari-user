import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:shimmer/shimmer.dart';

class AllOffersScreen extends ConsumerWidget {
  const AllOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(nearbyOffersProvider);
    final shopsAsync = ref.watch(nearbyShopsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      appBar: AppBar(
        title: Text(
          'Offers Near You',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: offersAsync.when(
            data: (offers) {
              final hPad = Responsive.horizontalPadding(context);
              final isTablet = Responsive.isTablet(context);
              if (offers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_offer_outlined,
                          size: isTablet ? 68.0 : 56.0, color: AppColors.textHint),
                      const SizedBox(height: 14),
                      Text(
                        'No active offers nearby',
                        style: GoogleFonts.poppins(
                            fontSize: isTablet ? 17.0 : 15.0, color: AppColors.textHint),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Check back soon for deals from local shops.',
                        style: GoogleFonts.poppins(
                            fontSize: isTablet ? 13.5 : 12.0, color: AppColors.textHint),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final shops = shopsAsync.value ?? [];

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 32),
                itemCount: offers.length,
                itemBuilder: (context, i) {
                  final offer = offers[i];
                  return _OfferListCard(
                    offer: offer,
                    index: i,
                    isDark: isDark,
                    onTap: () {
                      final match = shops.where((s) => s.id == offer.shopId).firstOrNull;
                      if (match == null) return;
                      context.push('/shop_details', extra: match);
                    },
                  );
                },
              );
            },
            loading: () => _AllOffersShimmer(isDark: isDark),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.textHint),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load offers',
                    style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textHint),
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

class _OfferListCard extends StatelessWidget {
  final Offer offer;
  final int index;
  final bool isDark;
  final VoidCallback onTap;

  const _OfferListCard({
    required this.offer,
    required this.index,
    required this.isDark,
    required this.onTap,
  });

  static const _gradients = [
    [Color(0xFFE8445A), Color(0xFFF76F83)],
    [Color(0xFF3730A3), Color(0xFF6366F1)],
    [Color(0xFF0F766E), Color(0xFF0D9488)],
    [Color(0xFFB45309), Color(0xFFF59E0B)],
    [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[index % _gradients.length];
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final isTablet = Responsive.isTablet(context);
    final isSmall = Responsive.isSmallPhone(context);
    final cardHeight = isTablet ? 126.0 : (isSmall ? 94.0 : 108.0);
    final panelWidth = isTablet ? 120.0 : (isSmall ? 86.0 : 100.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: colors[0].withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Left gradient panel
              Container(
                width: panelWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -8,
                      bottom: -12,
                      child: Text(
                        '${offer.discountPercentage.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 86.0 : (isSmall ? 60.0 : 72.0),
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.1),
                          height: 1,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${offer.discountPercentage.toInt()}%',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 36.0 : (isSmall ? 24.0 : 30.0),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          Text(
                            'OFF',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 15.0 : (isSmall ? 12.0 : 14.0),
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Right content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      isTablet ? 18.0 : 16.0, 14, isTablet ? 16.0 : 14.0, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.title,
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 15.0 : (isSmall ? 12.5 : 14.0),
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (offer.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              offer.description,
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 12.5 : (isSmall ? 10.5 : 11.5),
                                color: AppColors.textHint,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          if (offer.shopName.isNotEmpty) ...[
                            const Icon(
                              Icons.storefront_rounded,
                              size: 12,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                offer.shopName,
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 12.0 : (isSmall ? 10.0 : 11.0),
                                  color: AppColors.textHint,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else
                            const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 14.0 : 12.0,
                              vertical: isTablet ? 6.0 : 5.0,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: colors),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              'View Shop',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 11.5 : (isSmall ? 9.5 : 10.5),
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
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
  }
}

class _AllOffersShimmer extends StatelessWidget {
  final bool isDark;
  const _AllOffersShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final isTablet = Responsive.isTablet(context);
    final isSmall = Responsive.isSmallPhone(context);
    final cardHeight = isTablet ? 126.0 : (isSmall ? 94.0 : 108.0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 32),
          itemCount: 6,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Shimmer.fromColors(
              baseColor: isDark ? const Color(0xFF222C36) : Colors.grey.shade300,
              highlightColor: isDark ? const Color(0xFF2C3742) : Colors.grey.shade100,
              child: Container(
                height: cardHeight,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
