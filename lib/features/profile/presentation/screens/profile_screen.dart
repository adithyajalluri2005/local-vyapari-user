import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/theme_provider.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/services/role_service.dart';
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final authState = ref.watch(authProvider);
    final user = authState is Authenticated ? authState.user : null;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final initial = user?.email?.substring(0, 1).toUpperCase() ?? 'U';

    String themeModeLabel;
    IconData themeIcon;
    switch (themeMode) {
      case ThemeMode.system:
        themeModeLabel = 'System';
        themeIcon = Icons.brightness_auto_outlined;
      case ThemeMode.light:
        themeModeLabel = 'Light';
        themeIcon = Icons.light_mode_outlined;
      case ThemeMode.dark:
        themeModeLabel = 'Dark';
        themeIcon = Icons.dark_mode_outlined;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Header with gradient ─────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    children: [
                      // Top row
                      Row(
                        children: [
                          Text(
                            'Profile',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Spacer(),
                          AnnotatedRegion<SystemUiOverlayStyle>(
                            value: SystemUiOverlayStyle.light,
                            child: const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Avatar + user info
                      Row(
                        children: [
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.email ?? 'User',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.phoneNumber ?? 'No phone added',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
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
            ),
          ),

          // ── Menu ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    children: [
                      _MenuSection(
                        items: [
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
                          _MenuItem(
                            icon: Icons.favorite_outline_rounded,
                            iconColor: const Color(0xFFDC2626),
                            label: 'Favorite products',
                            onTap: () => CustomSnackBar.showInfo(
                              context: context,
                              title: 'Coming soon',
                              message: 'Favorite Products will be available in the next update.',
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.storefront_outlined,
                            iconColor: AppTheme.primaryColor,
                            label: 'Favorite shops',
                            onTap: () => CustomSnackBar.showInfo(
                              context: context,
                              title: 'Coming soon',
                              message: 'Favorite Shops will be available in the next update.',
                            ),
                          ),
                          _MenuItem(
                            icon: Icons.chat_bubble_outline_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            label: 'My chats',
                            onTap: () => context.push('/chats'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MenuSection(
                        items: [
                          _MenuItem(
                            icon: Icons.notifications_none_rounded,
                            iconColor: const Color(0xFFD97706),
                            label: 'Notification settings',
                            onTap: () => CustomSnackBar.showInfo(
                              context: context,
                              title: 'Coming soon',
                              message: 'Notification Settings will be available in the next update.',
                            ),
                          ),
                          _MenuItem(
                            icon: themeIcon,
                            iconColor: isDark ? const Color(0xFF8FBAD8) : const Color(0xFF1B3B56),
                            label: 'App theme',
                            trailing: Text(
                              themeModeLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppTheme.inkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () => _showThemeSheet(context, ref),
                          ),
                          _MenuItem(
                            icon: Icons.share_outlined,
                            iconColor: AppTheme.primaryColor,
                            label: 'Share app',
                            onTap: () => _showShareSheet(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MenuSection(
                        items: [
                          _MenuItem(
                            icon: Icons.storefront_outlined,
                            iconColor: const Color(0xFF1B3B56),
                            label: 'Switch to Vendor app',
                            onTap: () async {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator()),
                              );
                              try {
                                await RoleService.instance.switchRoleAndLaunchApp('merchant');
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  CustomSnackBar.showError(
                                    context: context,
                                    title: 'Switch Failed',
                                    message: e.toString().replaceFirst('Exception: ', ''),
                                  );
                                }
                              }
                            },
                          ),
                          _MenuItem(
                            icon: Icons.logout_rounded,
                            iconColor: AppTheme.errorColor,
                            iconBg: AppTheme.errorColor.withValues(alpha: 0.1),
                            label: 'Log out',
                            labelColor: AppTheme.errorColor,
                            onTap: () => ref.read(authProvider.notifier).logout(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeModeProvider);
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'App theme',
              style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (final entry in const [
              (ThemeMode.system, 'System default', Icons.brightness_auto_outlined),
              (ThemeMode.light, 'Light', Icons.light_mode_outlined),
              (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(entry.$3, color: AppTheme.primaryColor),
                title: Text(entry.$2, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                trailing: current == entry.$1
                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor)
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
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Share Local Vyapari',
              style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.copy_outlined, color: AppTheme.primaryColor),
              title: Text('Copy link', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
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
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.share_outlined, color: Colors.green),
              title: Text('Share via WhatsApp', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Menu components
// ─────────────────────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              items[i],
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 54,
                  endIndent: 0,
                  color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? iconBg;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    this.iconBg,
    required this.label,
    this.labelColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg ?? iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: labelColor ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.inkFaint,
                ),
          ],
        ),
      ),
    );
  }
}
