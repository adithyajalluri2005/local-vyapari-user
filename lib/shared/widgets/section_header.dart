import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = Responsive.isTablet(context);
    final isSmall = Responsive.isSmallPhone(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 17.0 : (isSmall ? 13.5 : 15.0),
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class SeeAllChip extends StatelessWidget {
  final VoidCallback onTap;
  const SeeAllChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = Responsive.isTablet(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 14.0 : 12.0, vertical: 5),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          'See all',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 13.0 : 12.0,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white.withValues(alpha: 0.87) : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
