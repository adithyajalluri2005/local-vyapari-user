import 'package:flutter/material.dart';
import 'responsive.dart';

import 'app_radius.dart';

class AppSizes {
  static const double radiusSmall = AppRadius.sm;
  static const double radiusMedium = AppRadius.md;
  static const double radiusLarge = AppRadius.lg;
  static const double radiusExtraLarge = AppRadius.xl;

  static double paddingSmall(BuildContext context) => Responsive.isSmallPhone(context) ? 8.0 : 12.0;
  static double paddingMedium(BuildContext context) => Responsive.isSmallPhone(context) ? 14.0 : 18.0;
  static double paddingLarge(BuildContext context) => Responsive.isTablet(context) ? 28.0 : 22.0;
  static double paddingExtraLarge(BuildContext context) => Responsive.isTablet(context) ? 40.0 : 32.0;

  static double offerCardWidth(BuildContext context) {
    double width = MediaQuery.sizeOf(context).width;
    if (Responsive.isTablet(context)) return width * 0.38;
    return width * 0.72;
  }

  static double offerCardHeight(BuildContext context) {
    return Responsive.isTablet(context) ? 160.0 : 142.0;
  }

  static double shopCardWidth(BuildContext context) {
    if (Responsive.isTablet(context)) return 200.0;
    return 168.0;
  }

  static double shopCardHeight(BuildContext context) {
    return Responsive.isTablet(context) ? 230.0 : 200.0;
  }

  static double shopImageHeight(BuildContext context) {
    return Responsive.isTablet(context) ? 140.0 : 118.0;
  }

  static int productGridColumnCount(BuildContext context) {
    if (Responsive.isTablet(context)) {
      return MediaQuery.orientationOf(context) == Orientation.portrait ? 3 : 4;
    }
    return 2;
  }

  static double productGridAspectRatio(BuildContext context) {
    if (Responsive.isTablet(context)) return 0.82;
    if (Responsive.isSmallPhone(context)) return 0.64;
    return 0.68;
  }

  // ── Offer banner horizontal carousel ─────────────────────────────────────
  static double offerBannerCardWidth(BuildContext context) {
    if (Responsive.isLargeTablet(context)) return 230.0;
    if (Responsive.isTablet(context)) return 210.0;
    if (Responsive.isSmallPhone(context)) return 162.0;
    return 185.0;
  }

  static double offerBannerCardHeight(BuildContext context) {
    if (Responsive.isTablet(context)) return 200.0;
    if (Responsive.isSmallPhone(context)) return 168.0;
    return 182.0;
  }

  // ── Hero spotlight card ───────────────────────────────────────────────────
  static double heroSpotlightHeight(BuildContext context) {
    if (Responsive.isLargeTablet(context)) return 240.0;
    if (Responsive.isTablet(context)) return 215.0;
    if (Responsive.isSmallPhone(context)) return 170.0;
    return 192.0;
  }

  // ── Shop active-offers horizontal carousel ────────────────────────────────
  static double shopOfferCardWidth(BuildContext context) {
    if (Responsive.isTablet(context)) return 220.0;
    if (Responsive.isSmallPhone(context)) return 172.0;
    return 194.0;
  }

  static double shopOfferListHeight(BuildContext context) {
    if (Responsive.isTablet(context)) return 200.0;
    if (Responsive.isSmallPhone(context)) return 162.0;
    return 180.0;
  }

  // ── Offers screen tile ────────────────────────────────────────────────────
  static double offerTileCarouselHeight(BuildContext context) {
    if (Responsive.isTablet(context)) return 172.0;
    if (Responsive.isSmallPhone(context)) return 138.0;
    return 155.0;
  }

  static double offerTileDiscountBadgeWidth(BuildContext context) {
    if (Responsive.isTablet(context)) return 108.0;
    if (Responsive.isSmallPhone(context)) return 82.0;
    return 94.0;
  }
}
