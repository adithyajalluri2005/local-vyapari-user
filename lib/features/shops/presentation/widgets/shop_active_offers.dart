import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_offers_provider.dart';

class ShopActiveOffers extends ConsumerWidget {
  final String shopId;
  final double padding;

  const ShopActiveOffers({
    super.key,
    required this.shopId,
    required this.padding,
  });

  static const _offerCardGradients = [
    [Color(0xFFE8445A), Color(0xFFF76F83)],
    [Color(0xFF3730A3), Color(0xFF6366F1)],
    [Color(0xFF0F766E), Color(0xFF0D9488)],
    [Color(0xFFB45309), Color(0xFFF59E0B)],
    [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(shopOffersProvider(shopId));
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
}
