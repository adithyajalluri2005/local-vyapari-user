import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/empty_section.dart';

const _kShimmerDark = Color(0xFF2A2A3E);
const _kShimmerDarkHL = Color(0xFF3A3A4E);

class OfferBannerList extends StatelessWidget {
  final AsyncValue<List<Offer>> offersAsync;
  final double hp;
  final bool isDark;
  final void Function(Offer) onOfferTap;

  const OfferBannerList({
    super.key,
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
    final cardHeight = AppSizes.offerBannerCardHeight(context);
    return SizedBox(
      height: cardHeight,
      child: offersAsync.when(
        skipLoadingOnReload: false,
        data: (offers) {
          if (offers.isEmpty) {
            return const EmptySection(
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
              final daysLeft = offer.endDate?.difference(DateTime.now()).inDays;
              final cardWidth = AppSizes.offerBannerCardWidth(context);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FadeInSlide(
                  delay: Duration(milliseconds: 60 * i),
                  child: GestureDetector(
                    onTap: () => onOfferTap(offer),
                    child: Container(
                      width: cardWidth,
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
                          Container(
                            height: Responsive.isTablet(ctx) ? 88.0 : (Responsive.isSmallPhone(ctx) ? 64.0 : 76.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.isSmallPhone(ctx) ? 10.0 : 14.0,
                              vertical: 10,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${offer.discountPercentage.toInt()}%\nOFF',
                                    style: GoogleFonts.poppins(
                                      fontSize: Responsive.isTablet(ctx) ? 28.0 : (Responsive.isSmallPhone(ctx) ? 20.0 : 24.0),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.local_offer_rounded,
                                  size: Responsive.isTablet(ctx) ? 40.0 : (Responsive.isSmallPhone(ctx) ? 28.0 : 34.0),
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  if (offer.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      offer.description,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: AppColors.textHint,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const Spacer(),
                                  if (daysLeft != null && daysLeft >= 0) ...[
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_outlined,
                                          size: 10,
                                          color: daysLeft <= 1
                                              ? AppColors.error
                                              : colors[0].withValues(alpha: 0.8),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          daysLeft == 0
                                              ? 'Ends today'
                                              : '$daysLeft days left',
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: daysLeft <= 1
                                                ? AppColors.error
                                                : colors[0].withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ],
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
                width: AppSizes.offerBannerCardWidth(context),
                height: cardHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
        ),
        error: (_, _) => const EmptySection(
          icon: Icons.error_outline,
          message: 'Could not load offers',
        ),
      ),
    );
  }
}
