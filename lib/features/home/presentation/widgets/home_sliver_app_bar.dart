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
    final isSmallPhone = Responsive.isSmallPhone(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Cap location text width so it never crowds the action buttons.
    // Reserve ≈ icon(22) + gap(6) + chevron(18) + actions(~52) + titleSpacing + buffer.
    final locationMaxWidth = (screenWidth * (isTablet ? 0.40 : 0.44)).clamp(
      isSmallPhone ? 110.0 : 140.0,
      isTablet ? 280.0 : 200.0,
    );

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
              size: isSmallPhone ? 18.0 : 22.0,
            ),
            SizedBox(width: isSmallPhone ? 4 : 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Browsing near',
                  style: GoogleFonts.poppins(
                    fontSize: isSmallPhone ? 9.0 : 10.0,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: locationMaxWidth),
                      child: Text(
                        locationLoading
                            ? 'Detecting location...'
                            : locationName.isNotEmpty
                                ? locationName
                                : 'Set your location',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 17.0 : isSmallPhone ? 13.0 : 15.0,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: isSmallPhone ? 16.0 : 18.0,
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
          icon: Icon(
            Icons.notifications_none_rounded,
            size: isSmallPhone ? 20.0 : 22.0,
          ),
          onPressed: onNotificationTap,
          tooltip: 'Notifications',
        ),
        SizedBox(width: isSmallPhone ? 2 : 4),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(isTablet ? 62.0 : isSmallPhone ? 52.0 : 56.0),
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
              height: isTablet ? 48.0 : isSmallPhone ? 40.0 : 44.0,
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
                  SizedBox(width: isSmallPhone ? 10 : 14),
                  Icon(
                    Icons.search_rounded,
                    size: isSmallPhone ? 18.0 : 20.0,
                    color: AppColors.textHint,
                  ),
                  SizedBox(width: isSmallPhone ? 6 : 10),
                  Flexible(
                    child: Text(
                      'Search shops, products & offers...',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 15.0 : isSmallPhone ? 12.0 : 13.5,
                        color: AppColors.textHint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: isSmallPhone ? 10 : 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
