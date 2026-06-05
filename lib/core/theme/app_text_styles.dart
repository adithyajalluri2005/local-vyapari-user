import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'responsive.dart';

class AppTextStyles {
  static TextStyle displayLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.poppins(
      fontSize: Responsive.isTablet(context) ? 36 : 32,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color ?? Colors.white,
    );
  }

  static TextStyle titleLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.poppins(
      fontSize: Responsive.isTablet(context) ? 20 : 18,
      fontWeight: fontWeight ?? FontWeight.w700,
      color: color,
    );
  }

  static TextStyle titleMedium(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.poppins(
      fontSize: Responsive.isTablet(context) ? 17 : 15,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }

  static TextStyle titleSmall(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.poppins(
      fontSize: Responsive.isTablet(context) ? 15 : 13,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color,
    );
  }

  static TextStyle bodyLarge(BuildContext context, {Color? color, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.poppins(
      fontSize: Responsive.isTablet(context) ? 16 : 15,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color,
      height: height ?? 1.5,
    );
  }

  static TextStyle bodyMedium(BuildContext context, {Color? color, FontWeight? fontWeight, double? height}) {
    return GoogleFonts.poppins(
      fontSize: Responsive.isTablet(context) ? 14 : 13,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? Colors.white70,
      height: height ?? 1.5,
    );
  }

  static TextStyle labelLarge(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: color ?? Colors.white,
    );
  }

  static TextStyle caption(BuildContext context, {Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? AppColors.textHint,
    );
  }
}
