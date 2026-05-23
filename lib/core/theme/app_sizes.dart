import 'package:flutter/material.dart';
import 'responsive.dart';

import 'app_radius.dart';

class AppSizes {
  // Border radius tokens mapped to AppRadius
  static const double radiusSmall = AppRadius.sm;
  static const double radiusMedium = AppRadius.md;
  static const double radiusLarge = AppRadius.lg;
  static const double radiusExtraLarge = AppRadius.xl;

  // Responsive padding/margin helper
  static double paddingSmall(BuildContext context) => Responsive.isSmallPhone(context) ? 8.0 : 12.0;
  static double paddingMedium(BuildContext context) => Responsive.isSmallPhone(context) ? 12.0 : 16.0;
  static double paddingLarge(BuildContext context) => Responsive.isTablet(context) ? 24.0 : 20.0;
  static double paddingExtraLarge(BuildContext context) => Responsive.isTablet(context) ? 36.0 : 28.0;

  // Horizontal list sizes (Trending Offers, Nearby Shops)
  static double offerCardWidth(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (Responsive.isTablet(context)) return width * 0.4;
    return width * 0.8; // Intentional peeking fraction
  }

  static double offerCardHeight(BuildContext context) {
    return Responsive.isTablet(context) ? 130.0 : 115.0;
  }

  static double shopCardWidth(BuildContext context) {
    if (Responsive.isTablet(context)) return 190.0;
    return 160.0;
  }

  static double shopCardHeight(BuildContext context) {
    return Responsive.isTablet(context) ? 220.0 : 190.0;
  }

  static double shopImageHeight(BuildContext context) {
    return Responsive.isTablet(context) ? 135.0 : 110.0;
  }

  // Recommended Products Grid details
  static int productGridColumnCount(BuildContext context) {
    if (Responsive.isTablet(context)) {
      // 3 columns in portrait, 4 in landscape
      return MediaQuery.of(context).orientation == Orientation.portrait ? 3 : 4;
    }
    return 2; // Mobile standard
  }

  static double productGridAspectRatio(BuildContext context) {
    // Return higher aspect ratio on tablets to avoid stretched cards
    if (Responsive.isTablet(context)) return 0.85;
    if (Responsive.isSmallPhone(context)) return 0.68;
    return 0.72;
  }
}
