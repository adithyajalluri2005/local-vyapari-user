import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'responsive.dart';

class AppTextStyles {
  static TextStyle titleLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    double baseSize = Responsive.isTablet(context) ? 24.0 : (Responsive.isSmallPhone(context) ? 18.0 : 20.0);
    return GoogleFonts.inter(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.bold,
      color: color,
    );
  }

  static TextStyle titleMedium(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    double baseSize = Responsive.isTablet(context) ? 18.0 : (Responsive.isSmallPhone(context) ? 14.0 : 16.0);
    return GoogleFonts.inter(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }

  static TextStyle titleSmall(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    double baseSize = Responsive.isTablet(context) ? 16.0 : (Responsive.isSmallPhone(context) ? 12.0 : 14.0);
    return GoogleFonts.inter(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }

  static TextStyle bodyLarge(BuildContext context, {Color? color, FontWeight? fontWeight, double? height}) {
    double baseSize = Responsive.isTablet(context) ? 16.0 : (Responsive.isSmallPhone(context) ? 13.0 : 14.0);
    return GoogleFonts.inter(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }

  static TextStyle bodyMedium(BuildContext context, {Color? color, FontWeight? fontWeight, double? height}) {
    double baseSize = Responsive.isTablet(context) ? 14.0 : (Responsive.isSmallPhone(context) ? 11.0 : 12.0);
    return GoogleFonts.inter(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      height: height,
    );
  }

  static TextStyle labelLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    double baseSize = Responsive.isTablet(context) ? 16.0 : (Responsive.isSmallPhone(context) ? 13.0 : 14.0);
    return GoogleFonts.inter(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }
}
