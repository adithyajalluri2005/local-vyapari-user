import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';

class HomeSliverAppBar extends StatelessWidget {
  final String locationName;
  final bool locationLoading;
  final bool isDark;
  final VoidCallback onLocationTap;
  final VoidCallback onNotificationTap;
  final VoidCallback? onSearchTap;

  const HomeSliverAppBar({
    super.key,
    required this.locationName,
    required this.locationLoading,
    required this.isDark,
    required this.onLocationTap,
    required this.onNotificationTap,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final hPad = Responsive.horizontalPadding(context);
    final isTablet = Responsive.isTablet(context);
    return SliverAppBar(
      automaticallyImplyLeading: false,
      titleSpacing: hPad,
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: GestureDetector(
        onTap: onLocationTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_rounded,
              color: textColor,
              size: 22,
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Browsing near',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isTablet ? 260.0 : 180.0),
                      child: Text(
                        locationLoading
                            ? 'Detecting location...'
                            : locationName.isNotEmpty
                                ? locationName
                                : 'Set your location',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 17.0 : 15.0,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: textColor,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, size: 22),
          onPressed: onNotificationTap,
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(isTablet ? 62.0 : 56.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.border.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 10),
          child: GestureDetector(
            onTap: onSearchTap,
            child: Container(
              height: isTablet ? 48.0 : 44.0,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: isDark ? Colors.white12 : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Search shops, products & offers...',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 15.0 : 13.5,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
