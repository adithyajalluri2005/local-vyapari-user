import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'responsive.dart';

class AppTextStyles {
  static TextStyle displayLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    double baseSize = Responsive.isTablet(context) ? 40.0 : (Responsive.isSmallPhone(context) ? 30.0 : 34.0);
    return GoogleFonts.plusJakartaSans(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w800,
      color: color,
      letterSpacing: -0.8,
    );
  }

  static TextStyle titleLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    double baseSize = Responsive.isTablet(context) ? 26.0 : (Responsive.isSmallPhone(context) ? 20.0 : 22.0);
    return GoogleFonts.plusJakartaSans(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      letterSpacing: -0.3,
    );
  }

  static TextStyle titleMedium(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    double baseSize = Responsive.isTablet(context) ? 20.0 : (Responsive.isSmallPhone(context) ? 15.0 : 17.0);
    return GoogleFonts.plusJakartaSans(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
      letterSpacing: -0.2,
    );
  }

  static TextStyle titleSmall(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    double baseSize = Responsive.isTablet(context) ? 17.0 : (Responsive.isSmallPhone(context) ? 13.0 : 15.0);
    return GoogleFonts.plusJakartaSans(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }

  static TextStyle bodyLarge(BuildContext context, {Color? color, FontWeight? fontWeight, double? height}) {
    double baseSize = Responsive.isTablet(context) ? 16.0 : (Responsive.isSmallPhone(context) ? 13.5 : 14.5);
    return GoogleFonts.plusJakartaSans(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: height ?? 1.5,
    );
  }

  static TextStyle bodyMedium(BuildContext context, {Color? color, FontWeight? fontWeight, double? height}) {
    double baseSize = Responsive.isTablet(context) ? 14.0 : (Responsive.isSmallPhone(context) ? 11.5 : 12.5);
    return GoogleFonts.plusJakartaSans(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: height ?? 1.45,
    );
  }

  static TextStyle labelLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    double baseSize = Responsive.isTablet(context) ? 16.0 : (Responsive.isSmallPhone(context) ? 13.0 : 14.0);
    return GoogleFonts.plusJakartaSans(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }

  static TextStyle caption(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    double baseSize = Responsive.isTablet(context) ? 12.0 : (Responsive.isSmallPhone(context) ? 10.0 : 11.0);
    return GoogleFonts.plusJakartaSans(
      fontSize: baseSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
    );
  }
}
