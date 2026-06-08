import 'package:flutter/material.dart';

class Responsive {
  // ── Breakpoints use shortestSide so landscape phones get phone layout if needed,
  // but we can check orientations as well for layout-adaptive components.
  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  static bool isLargeTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 840;

  // ── Backward compat aliases ────────────────────────────────────────────
  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  static bool isMobile(BuildContext context) => isPhone(context);

  // ── Responsive padding ─────────────────────────────────────────────────
  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1024) return 32;
    if (w >= 720) return 28;
    if (w >= 600) return 24;
    return 16;
  }

  // ── Grid columns ───────────────────────────────────────────────────────
  static int shopGridColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return 3;
    if (w >= 900) return 2;
    return 1;
  }

  static int productGridColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (w >= 1200) return 4;
    if (w >= 900) return 3;
    if (w >= 600) return 2;
    if (landscape) return 3;
    return 2;
  }

  // ── Navigation ─────────────────────────────────────────────────────────
  // Use nav rail on tablet, or on phone when in landscape to maximize vertical screen area
  static bool useNavRail(BuildContext context) =>
      isTablet(context) || MediaQuery.of(context).orientation == Orientation.landscape;
      
  static bool useExtendedRail(BuildContext context) => isLargeTablet(context);

  // ── Scale helpers ──────────────────────────────────────────────────────
  static double scaleFactor(BuildContext context) {
    if (isLargeTablet(context)) return 1.25;
    if (isTablet(context)) return 1.15;
    if (isSmallPhone(context)) return 0.85;
    return 1.0;
  }

  // ── Misc helpers ───────────────────────────────────────────────────────
  static double chartHeight(BuildContext context) => isTablet(context) ? 210 : 160;

  static double heroTextScale(BuildContext context) => isTablet(context) ? 1.15 : 1.0;

  static bool useStatsGrid(BuildContext context) => isTablet(context);

  // ── Legacy static fields (kept for callsites that call Responsive.init) ─
  static double get screenWidth => _width;
  static double get screenHeight => _height;
  static double get horizontalPaddingStatic => _hPad;
  static Orientation get orientation => _orientation;

  static double _width = 0;
  static double _height = 0;
  static double _hPad = 16;
  static Orientation _orientation = Orientation.portrait;

  static void init(BuildContext context) {
    final mq = MediaQuery.of(context);
    _width = mq.size.width;
    _height = mq.size.height;
    _orientation = mq.orientation;
    _hPad = horizontalPadding(context);
  }

  static double widthMultiplier(BuildContext context, double percent) =>
      MediaQuery.of(context).size.width * (percent / 100);

  static double heightMultiplier(BuildContext context, double percent) =>
      MediaQuery.of(context).size.height * (percent / 100);

  static double getSafeAreaTop(BuildContext context) => MediaQuery.of(context).padding.top;
  static double getSafeAreaBottom(BuildContext context) => MediaQuery.of(context).padding.bottom;
}

// ── Extensions ────────────────────────────────────────────────────────────────

extension ResponsiveContext on BuildContext {
  bool get isPhone => Responsive.isPhone(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isLargeTablet => Responsive.isLargeTablet(this);
  bool get isSmallPhone => Responsive.isSmallPhone(this);
  bool get isMobile => Responsive.isMobile(this);
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  Orientation get orientation => MediaQuery.of(this).orientation;
  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => orientation == Orientation.portrait;
  double get horizontalPadding => Responsive.horizontalPadding(this);
  double get textScaleFactor => MediaQuery.textScalerOf(this).scale(1.0);

  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isLargeTablet && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
}

extension ResponsiveNumeric on num {
  double scale(BuildContext context) => toDouble() * Responsive.scaleFactor(context);
  Widget get verticalSpace => SizedBox(height: toDouble());
  Widget get horizontalSpace => SizedBox(width: toDouble());
  Widget verticalSpaceScaled(BuildContext context) => SizedBox(height: scale(context));
  Widget horizontalSpaceScaled(BuildContext context) => SizedBox(width: scale(context));
}
