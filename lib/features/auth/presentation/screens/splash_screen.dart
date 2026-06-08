import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
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
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  void _navigate() {
    if (!mounted) return;

    final authState = ref.read(authProvider);

    if (authState is AuthInitial || authState is AuthLoading) {
      // Still warming up, retry in 200ms
      Future.delayed(const Duration(milliseconds: 200), _navigate);
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
    ref.watch(authProvider); // Ensure state changes trigger updates if needed
    Responsive.init(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
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
                  errorBuilder: (_, _, _) => Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
      ),
    );
  }
}
