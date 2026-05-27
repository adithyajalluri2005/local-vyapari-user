import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/services/role_service.dart';
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final authState = ref.watch(authProvider);
    final user = authState is Authenticated ? authState.user : null;
    
    final avatarRadius = Responsive.isTablet(context) ? 60.0 : 50.0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.paddingMedium(context), 
                vertical: AppSizes.paddingLarge(context),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: AppTextStyles.titleLarge(context, color: AppTheme.primaryColor).copyWith(
                        fontSize: avatarRadius * 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.email ?? 'User',
                    style: AppTextStyles.titleLarge(context, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.phoneNumber ?? 'No Phone Added',
                    style: AppTextStyles.bodyLarge(context, color: Colors.grey),
                  ),
                  SizedBox(height: AppSizes.paddingLarge(context)),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusLarge)),
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildProfileMenuItem(
                          context,
                          icon: Icons.location_on_outlined,
                          title: 'Saved Locations',
                          onTap: () {
                            CustomSnackBar.showInfo(
                              context: context,
                              title: 'Coming Soon',
                              message: 'Saved Locations feature will be available in the next update.',
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildProfileMenuItem(
                          context,
                          icon: Icons.favorite_border,
                          title: 'Favorite Products',
                          onTap: () {
                            CustomSnackBar.showInfo(
                              context: context,
                              title: 'Coming Soon',
                              message: 'Favorite Products feature will be available in the next update.',
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildProfileMenuItem(
                          context,
                          icon: Icons.storefront_outlined,
                          title: 'Favorite Shops',
                          onTap: () {
                            CustomSnackBar.showInfo(
                              context: context,
                              title: 'Coming Soon',
                              message: 'Favorite Shops feature will be available in the next update.',
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildProfileMenuItem(
                          context,
                          icon: Icons.chat_outlined,
                          title: 'My Chats',
                          onTap: () => context.push('/chats'),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildProfileMenuItem(
                          context,
                          icon: Icons.notifications_none_outlined,
                          title: 'Notification Settings',
                          onTap: () {
                            CustomSnackBar.showInfo(
                              context: context,
                              title: 'Coming Soon',
                              message: 'Notification Settings feature will be available in the next update.',
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildProfileMenuItem(
                          context,
                          icon: Icons.share_outlined,
                          title: 'Share App',
                          onTap: () => _showShareAppSheet(context),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildProfileMenuItem(
                          context,
                          icon: Icons.storefront_outlined,
                          title: 'Switch to Vendor App',
                          onTap: () async {
                            try {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              await RoleService.instance.switchRoleAndLaunchApp('merchant');

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
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
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildProfileMenuItem(
                          context,
                          icon: Icons.logout,
                          title: 'Logout',
                          iconColor: AppTheme.errorColor,
                          textColor: AppTheme.errorColor,
                          onTap: () => _logout(ref),
                        ),
                      ],
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

  Widget _buildProfileMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.primaryColor),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge(
          context, 
          color: textColor ?? Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showShareAppSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share Local Vyapari',
                style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.copy_outlined, color: AppTheme.primaryColor),
                title: const Text('Copy download link'),
                onTap: () async {
                  await Clipboard.setData(const ClipboardData(
                    text: 'Check out Local Vyapari App! Discover nearby retail shops and get exclusive local offers: https://localvyapari.com/download'
                  ));
                  if (context.mounted) {
                    Navigator.pop(context);
                    CustomSnackBar.showSuccess(
                      context: context,
                      title: 'Link Copied',
                      message: 'App link copied to your clipboard.',
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Colors.green),
                title: const Text('Share via WhatsApp'),
                onTap: () async {
                  final message = Uri.encodeComponent(
                    'Check out Local Vyapari App! Discover nearby retail shops and get exclusive local offers: https://localvyapari.com/download'
                  );
                  final url = Uri.parse('https://wa.me/?text=$message');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      CustomSnackBar.showError(
                        context: context,
                        title: 'Error',
                        message: 'Could not open WhatsApp.',
                      );
                    }
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
