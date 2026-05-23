import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
<<<<<<< HEAD
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
=======
import 'package:go_router/go_router.dart';
>>>>>>> 5d9a2e014a2907b44bd4cd1d8d56b775777733d4

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
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
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
}
