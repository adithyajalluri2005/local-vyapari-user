import 'package:flutter/material.dart';

enum DeviceType { smallPhone, mobile, tablet }

class Responsive {
  static late MediaQueryData mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double horizontalPadding;
  static late double verticalPadding;
  static late double devicePixelRatio;
  static late Orientation orientation;

  static void init(BuildContext context) {
    mediaQueryData = MediaQuery.of(context);
    screenWidth = mediaQueryData.size.width;
    screenHeight = mediaQueryData.size.height;
    orientation = mediaQueryData.orientation;
    devicePixelRatio = mediaQueryData.devicePixelRatio;

    // Breakpoint-based generic horizontal padding
    if (isTablet(context)) {
      horizontalPadding = screenWidth * 0.06; // 6% of screen width for tablets
      verticalPadding = screenHeight * 0.03;
    } else if (isSmallPhone(context)) {
      horizontalPadding = 12.0;
      verticalPadding = 12.0;
    } else {
      horizontalPadding = 16.0;
      verticalPadding = 16.0;
    }
  }

  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width >= 360 && MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  static DeviceType deviceType(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width < 360) return DeviceType.smallPhone;
    if (width < 600) return DeviceType.mobile;
    return DeviceType.tablet;
  }

  // Dynamic dimension methods based on percentage of screen dimensions
  static double widthMultiplier(BuildContext context, double percent) {
    return MediaQuery.of(context).size.width * (percent / 100);
  }

  static double heightMultiplier(BuildContext context, double percent) {
    return MediaQuery.of(context).size.height * (percent / 100);
  }

  // Safe Area helpers
  static double getSafeAreaTop(BuildContext context) => MediaQuery.of(context).padding.top;
  static double getSafeAreaBottom(BuildContext context) => MediaQuery.of(context).padding.bottom;
}
