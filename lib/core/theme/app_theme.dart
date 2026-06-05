import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';

class AppTheme {
  // ── Aliases kept for backward compat ─────────────────────────────
  static const Color primaryColor = AppColors.primary;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color primaryDark = AppColors.primaryDark;
  static const Color secondaryColor = AppColors.primaryLight;
  static const Color accentColor = AppColors.accent;
  static const Color accentLight = Color(0xFFEAF3E0);
  static const Color errorColor = AppColors.error;
  static const Color successColor = AppColors.success;
  static const Color warningColor = AppColors.warning;
  static const Color infoColor = AppColors.info;
  static const Color discountColor = AppColors.accent;
  static const Color stockBadgeColor = AppColors.warning;
  static const Color backgroundColor = AppColors.background;
  static const Color surfaceColor = AppColors.surface;
  static const Color surfaceMuted = AppColors.surfaceElevated;
  static const Color borderColor = AppColors.border;
  static const Color ink = AppColors.textPrimary;
  static const Color inkMuted = AppColors.textSecondary;
  static const Color inkFaint = AppColors.textHint;
  static const Color darkBackground = AppColors.darkScaffold;
  static const Color darkSurface = AppColors.darkSurface;
  static const Color darkSurfaceMuted = AppColors.darkElevated;
  static const Color darkBorder = Color(0x1AFFFFFF);
  static const Color darkInk = Color(0xFFFFFFFF);
  static const Color darkInkMuted = Color(0xB3FFFFFF);

  // =========================================================================
  // LIGHT
  // =========================================================================
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);

    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDDE8F5),
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceElevated,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme(base.textTheme, AppColors.textPrimary, AppColors.textSecondary),
      primaryTextTheme: _textTheme(base.primaryTextTheme, AppColors.textPrimary, AppColors.textSecondary),
      appBarTheme: _appBarTheme(AppColors.surface, AppColors.textPrimary),
      elevatedButtonTheme: _elevatedButtonTheme(AppColors.primary, Colors.white),
      filledButtonTheme: _filledButtonTheme(AppColors.primary, Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.primary, AppColors.border),
      textButtonTheme: _textButtonTheme(AppColors.primary),
      navigationBarTheme: _navBarTheme(AppColors.surface, AppColors.textPrimary, AppColors.border),
      inputDecorationTheme: _inputTheme(AppColors.surfaceElevated, AppColors.border, AppColors.textHint),
      cardTheme: _cardTheme(AppColors.surface, AppColors.border),
      chipTheme: _chipTheme(AppColors.surfaceElevated, AppColors.textPrimary, AppColors.border),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: _bottomSheetTheme(AppColors.surface),
      snackBarTheme: _snackBarTheme(AppColors.textPrimary),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  // =========================================================================
  // DARK
  // =========================================================================
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    const colorScheme = ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: Color(0xFF050F1C),
      primaryContainer: Color(0xFF1A3558),
      onPrimaryContainer: Color(0xFFBDD0E8),
      secondary: AppColors.accent,
      onSecondary: Color(0xFF0A1A05),
      surface: AppColors.darkSurface,
      onSurface: Color(0xFFFFFFFF),
      surfaceContainerHighest: AppColors.darkElevated,
      onSurfaceVariant: Color(0xB3FFFFFF),
      outline: Color(0x1AFFFFFF),
      outlineVariant: Color(0x1AFFFFFF),
      error: Color(0xFFF87171),
      onError: Color(0xFF1A0606),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkScaffold,
      textTheme: _textTheme(base.textTheme, Colors.white, const Color(0xB3FFFFFF)),
      primaryTextTheme: _textTheme(base.primaryTextTheme, Colors.white, const Color(0xB3FFFFFF)),
      appBarTheme: _appBarTheme(AppColors.darkScaffold, Colors.white),
      elevatedButtonTheme: _elevatedButtonTheme(AppColors.primaryLight, const Color(0xFF050F1C)),
      filledButtonTheme: _filledButtonTheme(AppColors.primaryLight, const Color(0xFF050F1C)),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.primaryLight, const Color(0x1AFFFFFF)),
      textButtonTheme: _textButtonTheme(AppColors.primaryLight),
      navigationBarTheme: _navBarTheme(AppColors.darkSurface, Colors.white, const Color(0x1AFFFFFF)),
      inputDecorationTheme: _inputTheme(AppColors.darkElevated, const Color(0x1AFFFFFF), const Color(0xFF94A3B8)),
      cardTheme: _cardTheme(AppColors.darkSurface, const Color(0x1AFFFFFF)),
      chipTheme: _chipTheme(AppColors.darkElevated, Colors.white, const Color(0x1AFFFFFF)),
      dividerTheme: const DividerThemeData(
        color: Color(0x1AFFFFFF),
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: _bottomSheetTheme(AppColors.darkSurface),
      snackBarTheme: _snackBarTheme(AppColors.darkElevated),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  // =========================================================================
  // Component builders
  // =========================================================================
  static TextTheme _textTheme(TextTheme base, Color text, Color muted) {
    final t = GoogleFonts.poppinsTextTheme(base);
    return t.copyWith(
      displayLarge: t.displayLarge?.copyWith(color: text, fontSize: 32, fontWeight: FontWeight.w700),
      headlineLarge: t.headlineLarge?.copyWith(color: text, fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge: t.titleLarge?.copyWith(color: text, fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(color: text, fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: t.bodyLarge?.copyWith(color: text, fontSize: 15, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium: t.bodyMedium?.copyWith(color: muted, fontSize: 13, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: t.bodySmall?.copyWith(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w400),
      labelLarge: t.labelLarge?.copyWith(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  static AppBarTheme _appBarTheme(Color bg, Color fg) {
    return AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      centerTitle: false,
      iconTheme: IconThemeData(color: fg, size: 24),
      systemOverlayStyle: bg.computeLuminance() > 0.5
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      titleTextStyle: GoogleFonts.poppins(
        color: fg,
        fontSize: 18,
        fontWeight: FontWeight.w700,
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
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme(Color bg, Color fg) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Color fg, Color border) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        side: BorderSide(color: border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(Color fg) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  static NavigationBarThemeData _navBarTheme(Color bg, Color ink, Color border) {
    return NavigationBarThemeData(
      backgroundColor: bg,
      indicatorColor: AppColors.primary.withValues(alpha: 0.1),
      elevation: 0,
      height: 62,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      surfaceTintColor: Colors.transparent,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary, size: 22);
        }
        return const IconThemeData(color: AppColors.textHint, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.poppins(
          color: selected ? AppColors.primary : AppColors.textHint,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 10,
        );
      }),
    );
  }

  static InputDecorationTheme _inputTheme(Color fill, Color border, Color hint) {
    OutlineInputBorder b(Color c, [double w = 0]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: GoogleFonts.poppins(color: hint, fontSize: 14, fontWeight: FontWeight.w400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: b(Colors.transparent),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border, width: 0.7),
      ),
      focusedBorder: b(AppColors.primary, 1.5),
      errorBorder: b(AppColors.error, 1.0),
      focusedErrorBorder: b(AppColors.error, 1.5),
    );
  }

  static CardThemeData _cardTheme(Color color, Color border) {
    return CardThemeData(
      color: color,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.055),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: border.withValues(alpha: 0.8), width: 0.7),
      ),
      margin: EdgeInsets.zero,
    );
  }

  static ChipThemeData _chipTheme(Color bg, Color ink, Color border) {
    return ChipThemeData(
      backgroundColor: bg,
      side: BorderSide(color: border.withValues(alpha: 0.8), width: 0.7),
      labelStyle: GoogleFonts.poppins(color: ink, fontSize: 12, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }

  static SnackBarThemeData _snackBarTheme(Color bg) {
    return SnackBarThemeData(
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      contentTextStyle: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
  }
}
