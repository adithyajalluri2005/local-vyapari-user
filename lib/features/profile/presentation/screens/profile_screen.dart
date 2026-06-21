import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/theme_provider.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/features/home/providers/navigation_provider.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
import 'package:local_vyapari_user/features/feedback/presentation/widgets/feedback_bottom_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState is Authenticated ? authState.user : null;
    final profileData = ref.watch(userProfileProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = profileData?['displayName']?.toString().trim() ?? user?.displayName?.trim() ?? '';
    final initial = name.isNotEmpty
        ? name.substring(0, 1).toUpperCase()
        : (user?.email?.substring(0, 1).toUpperCase() ?? 'U');
    final email = user?.email ?? '';
    final phone = user?.phoneNumber ?? '';

    String themeModeLabel;
    IconData themeIcon;
    switch (themeMode) {
      case ThemeMode.system:
        themeModeLabel = 'System default';
        themeIcon = Icons.brightness_auto_outlined;
      case ThemeMode.light:
        themeModeLabel = 'Light';
        themeIcon = Icons.light_mode_outlined;
      case ThemeMode.dark:
        themeModeLabel = 'Dark';
        themeIcon = Icons.dark_mode_outlined;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
        body: CustomScrollView(
          slivers: [
            // ── Hero header ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _ProfileHero(
                initial: initial,
                name: name,
                email: email,
                phone: phone,
                isDark: isDark,
              ),
            ),

            // ── Menu sections ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(Responsive.horizontalPadding(context), 20, Responsive.horizontalPadding(context), 32),
                    child: Column(
                      children: [
                        // Activity
                        FadeInSlide(
                          delay: const Duration(milliseconds: 100),
                          child: _MenuSection(
                            title: 'Activity',
                            items: [
                              _MenuItem(
                                icon: Icons.edit_outlined,
                                iconColor: AppColors.primary,
                                label: 'Edit Profile',
                                onTap: () => context.push('/edit_profile'),
                              ),
                              _MenuItem(
                                icon: Icons.chat_bubble_outline_rounded,
                                iconColor: const Color(0xFF7C3AED),
                                label: 'My Chats',
                                onTap: () => context.push('/chats'),
                              ),
                              _MenuItem(
                                icon: Icons.favorite_outline_rounded,
                                iconColor: AppColors.error,
                                label: 'Favourites',
                                onTap: () => ref.read(navigationIndexProvider.notifier).setIndex(3),
                              ),
                              _MenuItem(
                                icon: Icons.location_on_outlined,
                                iconColor: const Color(0xFF2563EB),
                                label: 'Saved locations',
                                onTap: () => CustomSnackBar.showInfo(
                                  context: context,
                                  title: 'Coming soon',
                                  message: 'Saved Locations will be available in the next update.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Preferences
                        FadeInSlide(
                          delay: const Duration(milliseconds: 160),
                          child: _MenuSection(
                            title: 'Preferences',
                            items: [
                              _MenuItem(
                                icon: themeIcon,
                                iconColor: AppColors.primary,
                                label: 'App theme',
                                trailing: Text(
                                  themeModeLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    color: AppColors.textHint,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: () => _showThemeSheet(context, ref),
                              ),
                              _MenuItem(
                                icon: Icons.shield_outlined,
                                iconColor: AppColors.primary,
                                label: 'Security',
                                onTap: () => context.push('/security'),
                              ),
                              _MenuItem(
                                icon: Icons.notifications_none_rounded,
                                iconColor: AppColors.warning,
                                label: 'Notification settings',
                                onTap: () => CustomSnackBar.showInfo(
                                  context: context,
                                  title: 'Coming soon',
                                  message: 'Notification Settings will be available in the next update.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // More
                        FadeInSlide(
                          delay: const Duration(milliseconds: 220),
                          child: _MenuSection(
                            title: 'More',
                            items: [
                              _MenuItem(
                                icon: Icons.share_outlined,
                                iconColor: AppColors.accent,
                                label: 'Share app',
                                onTap: () => _showShareSheet(context),
                              ),
                              _MenuItem(
                                icon: Icons.feedback_outlined,
                                iconColor: const Color(0xFF0EA5E9),
                                label: 'Send Feedback',
                                onTap: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => const FeedbackBottomSheet(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Logout
                        FadeInSlide(
                          delay: const Duration(milliseconds: 280),
                          child: ScaleOnTap(
                            onTap: () => ref.read(authProvider.notifier).logout(),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.2),
                                  width: 0.7,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.logout_rounded,
                                      size: 18, color: AppColors.error),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Log out',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeEntries = [
      (ThemeMode.system, 'System default', Icons.brightness_auto_outlined),
      (ThemeMode.light, 'Light', Icons.light_mode_outlined),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('App theme',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary)),
            const SizedBox(height: 12),
            for (final entry in themeEntries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(entry.$3, color: isDark ? Colors.white : AppColors.textPrimary),
                title: Text(entry.$2,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary)),
                trailing: current == entry.$1
                    ? Icon(Icons.check_circle_rounded, color: isDark ? Colors.white : AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(entry.$1);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }


  void _showShareSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Share Local Vyapari',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.copy_outlined, color: isDark ? Colors.white : AppColors.textPrimary),
              title: Text('Copy link',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary)),
              onTap: () async {
                await Clipboard.setData(const ClipboardData(
                  text: 'Check out Local Vyapari! Discover nearby shops & offers: https://localvyapari.com/download',
                ));
                if (context.mounted) {
                  Navigator.pop(context);
                  CustomSnackBar.showSuccess(
                    context: context,
                    title: 'Copied',
                    message: 'Link copied to clipboard.',
                  );
                }
              },
            ),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.share_outlined, color: Color(0xFF25D366)),
              title: Text('Share via WhatsApp',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary)),
              onTap: () async {
                final msg = Uri.encodeComponent(
                  'Check out Local Vyapari! Discover nearby shops & offers: https://localvyapari.com/download',
                );
                final url = Uri.parse('https://wa.me/?text=$msg');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile hero header ───────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final String initial;
  final String name;
  final String email;
  final String phone;
  final bool isDark;

  const _ProfileHero({
    required this.initial,
    required this.name,
    required this.email,
    required this.phone,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final isSmall = Responsive.isSmallPhone(context);
    final avatarSize = isTablet ? 80.0 : (isSmall ? 56.0 : 64.0);
    final hPad = Responsive.horizontalPadding(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 24.0 : 20.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 32.0 : (isSmall ? 22.0 : 26.0),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isTablet ? 18.0 : 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : (email.isNotEmpty ? email : 'User'),
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 17.0 : (isSmall ? 13.5 : 15.0),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (name.isNotEmpty && email.isNotEmpty)
                          Text(
                            email,
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 13.0 : (isSmall ? 11.0 : 12.0),
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 13.0 : (isSmall ? 11.0 : 12.0),
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        if (name.isEmpty && phone.isEmpty && email.isEmpty)
                          Text(
                            'No phone added',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 13.0 : (isSmall ? 11.0 : 12.0),
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu section & item ───────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.border,
              width: 0.7,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  Divider(
                    height: 1,
                    indent: 52,
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.border,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = Responsive.isTablet(context);
    final iconBoxSize = isTablet ? 40.0 : 34.0;
    final iconSize = isTablet ? 20.0 : 17.0;
    final labelSize = isTablet ? 15.0 : 14.0;
    return ScaleOnTap(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 18.0 : 14.0, vertical: isTablet ? 15.0 : 13.0),
        child: Row(
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
            SizedBox(width: isTablet ? 14.0 : 12.0),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: labelSize,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
