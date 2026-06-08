import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'responsive.dart';

class AppTextStyles {
  static TextStyle displayLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    final size = Responsive.isTablet(context)
        ? 36.0
        : (Responsive.isSmallPhone(context) ? 28.0 : 32.0);
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color ?? AppColors.textPrimary,
    );
  }

  static TextStyle titleLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    final size = Responsive.isTablet(context)
        ? 20.0
        : (Responsive.isSmallPhone(context) ? 16.0 : 18.0);
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
    );
  }

  static TextStyle titleMedium(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    final size = Responsive.isTablet(context)
        ? 17.0
        : (Responsive.isSmallPhone(context) ? 13.5 : 15.0);
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }

  static TextStyle titleSmall(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    final size = Responsive.isTablet(context)
        ? 15.0
        : (Responsive.isSmallPhone(context) ? 12.0 : 13.0);
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }

  static TextStyle bodyLarge(BuildContext context, {Color? color, FontWeight? fontWeight, double? height}) {
    final size = Responsive.isTablet(context)
        ? 16.0
        : (Responsive.isSmallPhone(context) ? 13.5 : 14.5);
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: height ?? 1.5,
    );
  }

  static TextStyle bodyMedium(BuildContext context, {Color? color, FontWeight? fontWeight, double? height}) {
    final size = Responsive.isTablet(context)
        ? 14.0
        : (Responsive.isSmallPhone(context) ? 11.5 : 12.5);
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? AppColors.textSecondary,
      height: height ?? 1.5,
    );
  }

  static TextStyle labelLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    final size = Responsive.isTablet(context)
        ? 14.0
        : (Responsive.isSmallPhone(context) ? 11.0 : 12.5);
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? AppColors.primary,
    );
  }

  static TextStyle caption(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    final size = Responsive.isTablet(context)
        ? 12.0
        : (Responsive.isSmallPhone(context) ? 10.0 : 11.0);
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? AppColors.textHint,
    );
  }
}
