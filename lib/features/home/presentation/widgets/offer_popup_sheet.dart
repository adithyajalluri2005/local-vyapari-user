import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';

class OfferPopupSheet extends StatelessWidget {
  final Offer offer;
  final VoidCallback onGrabTap;
  const OfferPopupSheet({super.key, required this.offer, required this.onGrabTap});

  static const _popupGradient = [AppColors.primary, AppColors.primaryLight];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final discPct = offer.discountPercentage.toInt();
    final isTablet = Responsive.isTablet(context);
    final isSmall = Responsive.isSmallPhone(context);
    final hPad = Responsive.horizontalPadding(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
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
                Container(
                  height: isTablet ? 72.0 : (isSmall ? 54.0 : 62.0),
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
                          Icon(
                            Icons.local_offer_rounded,
                            color: Colors.white,
                            size: isTablet ? 20.0 : 17.0,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'EXCLUSIVE DEAL',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14.0 : (isSmall ? 12.0 : 13.0),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(isTablet ? 28.0 : (isSmall ? 18.0 : 24.0)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$discPct',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 90.0 : (isSmall ? 64.0 : 76.0),
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.primary,
                                height: 1,
                              ),
                            ),
                            TextSpan(
                              text: '%',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 46.0 : (isSmall ? 32.0 : 38.0),
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.primary,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'OFF',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 17.0 : (isSmall ? 13.0 : 15.0),
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : AppColors.primaryLight,
                          letterSpacing: 5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DashedDivider(color: isDark ? Colors.white12 : AppColors.border),
                      const SizedBox(height: 18),
                      Text(
                        offer.title,
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 18.0 : (isSmall ? 14.0 : 16.0),
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
                                fontSize: isTablet ? 13.0 : (isSmall ? 11.0 : 12.0),
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onGrabTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                vertical: isTablet ? 16.0 : 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            textStyle: GoogleFonts.poppins(
                              fontSize: isTablet ? 16.0 : 15.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Grab This Deal'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Maybe Later',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 14.0 : (isSmall ? 12.0 : 13.0),
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedDivider extends StatelessWidget {
  final Color color;
  const DashedDivider({super.key, required this.color});

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
