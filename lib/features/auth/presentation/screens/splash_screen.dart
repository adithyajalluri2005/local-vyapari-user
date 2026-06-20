import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_spacing.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Start decrypting the location cache now so it's ready before we navigate.
    // Timeout at 600ms — well under the 800ms visual delay — so it can never
    // block navigation. Any error or timeout is silently swallowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(activeBrowsingLocationProvider.notifier)
          .preloadFromCache()
          .timeout(const Duration(milliseconds: 600))
          .catchError((_) {});
    });

    Future.delayed(const Duration(milliseconds: 800), _navigate);
  }

  void _navigate() {
    if (!mounted) return;

    final authState = ref.read(authProvider);

    if (authState is AuthInitial || authState is AuthLoading) {
      Future.delayed(const Duration(milliseconds: 500), _navigate);
      return;
    }

    if (authState is Unauthenticated || authState is AuthFailure) {
      context.go('/login');
    } else if (authState is NeedsDisplayName) {
      context.go('/display_name');
    } else if (authState is Authenticated) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInSlide(
              duration: const Duration(milliseconds: 800),
              slideOffset: 40.0,
              child: Image.asset(
                'assets/images/logo.png',
                height: Responsive.isTablet(context) ? 240 : 180,
                fit: BoxFit.contain,
              ),
            ),
            AppSpacing.verticalMd,
            FadeInSlide(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 400),
              slideOffset: 20.0,
              child: Text(
                'Discover local shops & exclusive offers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
            AppSpacing.verticalXl,
            const FadeInSlide(
              duration: Duration(milliseconds: 800),
              delay: Duration(milliseconds: 700),
              slideOffset: 10.0,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
