import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    // Watch authProvider to ensure the stream listener is initialized
    ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                // Fallback in case the image is not added yet
                return Icon(
                  Icons.storefront,
                  size: 100,
                  color: AppTheme.primaryColor,
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Local Vyapari',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover Nearby Shops & Offers',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.secondaryColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
