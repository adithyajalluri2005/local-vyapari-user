import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInSlide(
                duration: const Duration(milliseconds: 600),
                slideOffset: 24,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Local Vyapari',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Discover · Shop · Support Local',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white.withValues(alpha: 0.6),
                  strokeWidth: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
