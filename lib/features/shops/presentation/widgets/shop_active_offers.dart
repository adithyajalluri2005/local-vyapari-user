import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_offers_provider.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/services/analytics/analytics_service.dart';

class ShopActiveOffers extends ConsumerWidget {
  final String shopId;
  final double padding;

  const ShopActiveOffers({
    super.key,
    required this.shopId,
    required this.padding,
  });

  static void showOfferSheet(
    BuildContext context,
    Offer offer, {
    bool isDark = false,
    Shop? shop,
  }) {
    final colors = _offerCardGradients[0];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfferDetailsBottomSheet(
        offer: offer,
        colors: colors,
        isDark: isDark,
        shop: shop,
      ),
    );
  }

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
    final shopAsync = ref.watch(shopDetailsStreamProvider(shopId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shop = shopAsync.value;

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
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_offer_rounded, size: 13,
                            color: isDark ? Colors.white : AppColors.primary),
                        const SizedBox(width: 5),
                        Text(
                          'Active Offers',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      offers.length == 1 ? '1 deal' : '${offers.length} deals',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.accent,
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
                itemBuilder: (ctx, i) => _buildShopOfferCard(ctx, offers[i], i, isDark, shop),
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

  Widget _buildShopOfferCard(BuildContext context, Offer offer, int index, bool isDark, Shop? shop) {
    final colors = _offerCardGradients[index % _offerCardGradients.length];
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;
    final DateTime? endDate = offer.endDate;
    final int? daysLeft = endDate != null ? endDate.difference(DateTime.now()).inDays : null;
    final String description = offer.description;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              return _OfferDetailsBottomSheet(
                offer: offer,
                colors: colors,
                isDark: isDark,
                shop: shop,
              );
            },
          );
        },
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
                              color: daysLeft <= 1
                                  ? AppColors.error
                                  : isDark ? Colors.white60 : colors[0],
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
                                  color: daysLeft <= 1
                                      ? AppColors.error
                                      : isDark ? Colors.white60 : colors[0],
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
                            color: isDark ? Colors.white38 : AppColors.textHint,
                          ),
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

class _OfferDetailsBottomSheet extends StatelessWidget {
  final Offer offer;
  final List<Color> colors;
  final bool isDark;
  final Shop? shop;

  const _OfferDetailsBottomSheet({
    required this.offer,
    required this.colors,
    required this.isDark,
    this.shop,
  });

  Future<void> _launchMaps(BuildContext context, Shop shop) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${shop.location.latitude},${shop.location.longitude}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Maps')));
      }
    }
  }

  Future<void> _callShop(BuildContext context, Shop shop) async {
    final url = Uri.parse('tel:${shop.phone}');
    try {
      await launchUrl(url);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open dialer')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final subtitleColor = isDark ? Colors.white54 : AppColors.textHint;
    final borderColor = isDark ? Colors.white10 : AppColors.border;

    final DateTime? startDate = offer.startDate;
    final DateTime? endDate = offer.endDate;
    final String formattedStart = startDate != null
        ? DateFormat('dd MMM yyyy').format(startDate)
        : 'Start date N/A';
    final String formattedEnd = endDate != null
        ? DateFormat('dd MMM yyyy').format(endDate)
        : 'End date N/A';

    final int? daysLeft = endDate != null
        ? endDate.difference(DateTime.now()).inDays
        : null;

    final analyticsService = AnalyticsService();

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Exclusive Deal',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: isDark ? Colors.white70 : AppColors.textHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Offer Banner Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        '${offer.discountPercentage.toInt()}%\nOFF',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (daysLeft != null)
                            Text(
                              daysLeft == 0
                                  ? 'Ending today!'
                                  : daysLeft < 0
                                      ? 'Expired'
                                      : 'Hurry! Only $daysLeft days left',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            )
                          else
                            Text(
                              'Limited time offer',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Offer Description Section
              Text(
                'About the Offer',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                offer.description.isNotEmpty
                    ? offer.description
                    : 'Get flat discount with this active coupon. Present this offer at the shop checkout to redeem.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: secondaryTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Validity row
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: subtitleColor),
                  const SizedBox(width: 6),
                  Text(
                    'Validity: ',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor,
                    ),
                  ),
                  Text(
                    '$formattedStart - $formattedEnd',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: borderColor, height: 1),
              const SizedBox(height: 16),

              // Shop Details Section
              if (shop != null) ...[
                Text(
                  'Merchant Details',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: borderColor, width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop Logo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: shop!.shopLogo.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: shop!.shopLogo,
                                  fit: BoxFit.cover,
                                  cacheManager: AppCacheManager(),
                                  placeholder: (_, __) => Container(color: isDark ? Colors.white10 : Colors.black12),
                                  errorWidget: (_, __, ___) => const Icon(Icons.storefront_outlined),
                                )
                              : Container(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                  child: const Icon(Icons.storefront_outlined),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Name & Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    shop!.shopName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (shop!.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: Colors.blue, size: 16),
                                ],
                              ],
                            ),
                            if (shop!.rating > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${shop!.rating.toStringAsFixed(1)} (${shop!.totalReviews} reviews)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (shop!.location.address.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 13, color: subtitleColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      shop!.location.address,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: secondaryTextColor,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Actions row
                Row(
                  children: [
                    if (shop!.phone.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callShop(context, shop!),
                          icon: const Icon(Icons.phone_outlined, size: 16),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchMaps(context, shop!),
                        icon: const Icon(Icons.directions_outlined, size: 16),
                        label: const Text('Directions'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // close bottom sheet
                          analyticsService.trackProfileClick(shop!.ownerId);
                          context.push('/chat', extra: {
                            'shopId': shop!.id,
                            'shopName': shop!.shopName,
                            'shopLogo': shop!.shopLogo,
                          });
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text('Chat'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

