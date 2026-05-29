import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';

/// Central design system for Local Vyapari.
///
/// Principles: keep the brand green/navy identity, but lean on calm neutrals,
/// flat surfaces with hairline borders (instead of heavy shadows), generous
/// spacing and a single, consistent radius scale. The goal is a quiet,
/// professional feel rather than a loud, "template" look.
class AppTheme {
  // ---- Brand ----
  static const Color primaryColor = Color(0xFF659A41); // Brand Green
  static const Color primaryLight = Color(0xFF86B85E);
  static const Color primaryDark = Color(0xFF43702A);
  static const Color secondaryColor = Color(0xFF1B3B56); // Brand Navy Blue

  // ---- Semantic ----
  static const Color errorColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF15803D);
  static const Color warningColor = Color(0xFFB45309);
  static const Color infoColor = Color(0xFF2563EB);
  static const Color discountColor = Color(0xFF15803D);
  static const Color stockBadgeColor = Color(0xFFB45309);

  // ---- Light neutrals ----
  static const Color backgroundColor = Color(0xFFF7F8FA); // app background
  static const Color surfaceColor = Color(0xFFFFFFFF); // cards / sheets
  static const Color surfaceMuted = Color(0xFFF1F3F5); // input fills, chips
  static const Color borderColor = Color(0xFFE6E8EC); // hairline borders
  static const Color ink = Color(0xFF1A2433); // primary text
  static const Color inkMuted = Color(0xFF667085); // secondary text
  static const Color inkFaint = Color(0xFF98A2B3); // hints / disabled

  // ---- Dark neutrals ----
  static const Color darkBackground = Color(0xFF0E141B);
  static const Color darkSurface = Color(0xFF161E27);
  static const Color darkSurfaceMuted = Color(0xFF1E2832);
  static const Color darkBorder = Color(0xFF2A3640);
  static const Color darkInk = Color(0xFFF2F4F7);
  static const Color darkInkMuted = Color(0xFF98A2B3);

  // ---- Shared tokens ----
  static const double _radius = 14.0;

  // =========================================================================
  // LIGHT
  // =========================================================================
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);

    final colorScheme = const ColorScheme.light(
      primary: primaryColor,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE6F0DD),
      onPrimaryContainer: primaryDark,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      surface: surfaceColor,
      onSurface: ink,
      surfaceContainerHighest: surfaceMuted,
      onSurfaceVariant: inkMuted,
      outline: borderColor,
      outlineVariant: borderColor,
      error: errorColor,
      onError: Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: _textTheme(base.textTheme, ink, inkMuted),
      primaryTextTheme: _textTheme(base.primaryTextTheme, ink, inkMuted),
      appBarTheme: _appBarTheme(surfaceColor, ink),
      elevatedButtonTheme: _elevatedButtonTheme(primaryColor, Colors.white),
      filledButtonTheme: _filledButtonTheme(primaryColor, Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(primaryColor, borderColor),
      textButtonTheme: _textButtonTheme(primaryColor),
      navigationBarTheme: _navBarTheme(surfaceColor, ink, borderColor),
      inputDecorationTheme: _inputTheme(surfaceMuted, borderColor, inkFaint),
      cardTheme: _cardTheme(surfaceColor, borderColor),
      chipTheme: _chipTheme(surfaceMuted, ink, borderColor),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: _bottomSheetTheme(surfaceColor),
      snackBarTheme: _snackBarTheme(ink),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  // =========================================================================
  // DARK
  // =========================================================================
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    final colorScheme = const ColorScheme.dark(
      primary: primaryLight,
      onPrimary: Color(0xFF0E1B07),
      primaryContainer: Color(0xFF2C461B),
      onPrimaryContainer: Color(0xFFD6E8C6),
      secondary: Color(0xFF8FB8DA),
      onSecondary: Color(0xFF06121C),
      surface: darkSurface,
      onSurface: darkInk,
      surfaceContainerHighest: darkSurfaceMuted,
      onSurfaceVariant: darkInkMuted,
      outline: darkBorder,
      outlineVariant: darkBorder,
      error: Color(0xFFF87171),
      onError: Color(0xFF1A0606),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      textTheme: _textTheme(base.textTheme, darkInk, darkInkMuted),
      primaryTextTheme: _textTheme(base.primaryTextTheme, darkInk, darkInkMuted),
      appBarTheme: _appBarTheme(darkBackground, darkInk),
      elevatedButtonTheme: _elevatedButtonTheme(primaryLight, const Color(0xFF0E1B07)),
      filledButtonTheme: _filledButtonTheme(primaryLight, const Color(0xFF0E1B07)),
      outlinedButtonTheme: _outlinedButtonTheme(primaryLight, darkBorder),
      textButtonTheme: _textButtonTheme(primaryLight),
      navigationBarTheme: _navBarTheme(darkSurface, darkInk, darkBorder),
      inputDecorationTheme: _inputTheme(darkSurfaceMuted, darkBorder, darkInkMuted),
      cardTheme: _cardTheme(darkSurface, darkBorder),
      chipTheme: _chipTheme(darkSurfaceMuted, darkInk, darkBorder),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: _bottomSheetTheme(darkSurface),
      snackBarTheme: _snackBarTheme(darkSurfaceMuted),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  // =========================================================================
  // Component builders
  // =========================================================================
  static TextTheme _textTheme(TextTheme base, Color ink, Color muted) {
    final t = GoogleFonts.interTextTheme(base);
    return t.copyWith(
      displayLarge: t.displayLarge?.copyWith(color: ink, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displayMedium: t.displayMedium?.copyWith(color: ink, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displaySmall: t.displaySmall?.copyWith(color: ink, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineMedium: t.headlineMedium?.copyWith(color: ink, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      headlineSmall: t.headlineSmall?.copyWith(color: ink, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleLarge: t.titleLarge?.copyWith(color: ink, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: t.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(color: ink, fontWeight: FontWeight.w600),
      bodyLarge: t.bodyLarge?.copyWith(color: ink, height: 1.45),
      bodyMedium: t.bodyMedium?.copyWith(color: muted, height: 1.45),
      bodySmall: t.bodySmall?.copyWith(color: muted, height: 1.4),
      labelLarge: t.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    );
  }

  static AppBarTheme _appBarTheme(Color bg, Color fg) {
    return AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      centerTitle: false,
      iconTheme: IconThemeData(color: fg, size: 24),
      systemOverlayStyle: bg.computeLuminance() > 0.5
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      titleTextStyle: GoogleFonts.inter(
        color: fg,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(Color bg, Color fg) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.4),
        disabledForegroundColor: fg.withValues(alpha: 0.7),
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(Color bg, Color fg) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Color fg, Color border) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        side: BorderSide(color: border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(Color fg) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  static NavigationBarThemeData _navBarTheme(Color bg, Color ink, Color border) {
    return NavigationBarThemeData(
      backgroundColor: bg,
      indicatorColor: primaryColor.withValues(alpha: 0.12),
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      surfaceTintColor: Colors.transparent,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.circular)),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryColor, size: 24);
        }
        return IconThemeData(color: inkMuted, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          color: selected ? primaryColor : inkMuted,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 11.5,
        );
      }),
    );
  }

  static InputDecorationTheme _inputTheme(Color fill, Color border, Color hint) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: GoogleFonts.inter(color: hint, fontSize: 14, fontWeight: FontWeight.w400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: b(Colors.transparent),
      enabledBorder: b(Colors.transparent),
      focusedBorder: b(primaryColor, 1.5),
      errorBorder: b(errorColor),
      focusedErrorBorder: b(errorColor, 1.5),
    );
  }

  static CardThemeData _cardTheme(Color color, Color border) {
    return CardThemeData(
      color: color,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: BorderSide(color: border, width: 1),
      ),
      margin: EdgeInsets.zero,
    );
  }

  static ChipThemeData _chipTheme(Color bg, Color ink, Color border) {
    return ChipThemeData(
      backgroundColor: bg,
      side: BorderSide(color: border),
      labelStyle: GoogleFonts.inter(color: ink, fontSize: 12.5, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.circular)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  static BottomSheetThemeData _bottomSheetTheme(Color bg) {
    return BottomSheetThemeData(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  static SnackBarThemeData _snackBarTheme(Color bg) {
    return SnackBarThemeData(
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      elevation: 2,
      contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
  }
}
