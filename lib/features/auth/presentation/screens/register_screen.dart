import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/shared/utils/input_sanitizer.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final phone = '+91${_phoneController.text.trim()}';
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final emailError = InputSanitizer.validateEmail(email);
    if (emailError != null) {
      CustomSnackBar.showError(context: context, message: emailError, title: 'Validation Error');
      return;
    }

    if (_phoneController.text.trim().length != 10) {
      CustomSnackBar.showError(
        context: context,
        message: 'Please enter a valid 10-digit phone number',
        title: 'Validation Error',
      );
      return;
    }

    final passwordError = InputSanitizer.validatePassword(password);
    if (passwordError != null) {
      CustomSnackBar.showError(context: context, message: passwordError, title: 'Validation Error');
      return;
    }

    if (password != confirmPassword) {
      CustomSnackBar.showError(
        context: context,
        message: 'Passwords do not match',
        title: 'Validation Error',
      );
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(message: 'Sending OTP…'),
    );

    await authNotifier.sendRegistrationOtp(
      phone,
      onCodeSent: (verificationId) {
        Navigator.pop(context);
        showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final codeController = TextEditingController();
            bool isVerifying = false;

            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: Text(
                  'Verify your number',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'We sent a 6-digit OTP to $phone.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: AppTheme.inkMuted),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: '6-digit OTP',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [LengthLimitingTextInputFormatter(6)],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isVerifying ? null : () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            final code = codeController.text.trim();
                            if (code.length != 6) return;
                            setState(() => isVerifying = true);
                            final ok = await authNotifier.registerWithPhoneOtp(
                              verificationId: verificationId,
                              code: code,
                              email: email,
                              password: password,
                              phone: phone,
                            );
                            if (context.mounted) {
                              setState(() => isVerifying = false);
                              Navigator.pop(dialogContext, ok);
                            }
                          },
                    child: isVerifying
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verify & create'),
                  ),
                ],
              ),
            );
          },
        );
      },
      onFailed: (error) {
        Navigator.pop(context);
        if (error.contains('already registered')) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('Account exists', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              content: Text(
                'This phone number is already registered. You can log in with your password.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    context.pop();
                  },
                  child: const Text('Log in'),
                ),
              ],
            ),
          );
        } else {
          CustomSnackBar.showError(context: context, message: error, title: 'OTP Request Failed');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthFailure) {
        CustomSnackBar.showError(context: context, message: next.message, title: 'Registration Failed');
        ref.read(authProvider.notifier).resetState();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            // ── Brand header ──────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Create account',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.isTablet(context) ? 26 : 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start discovering local deals',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Form sheet ────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.backgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24, 28, 24,
                      MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email address',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone number',
                                prefixIcon: Icon(Icons.phone_outlined),
                                prefixText: '+91 ',
                              ),
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [LengthLimitingTextInputFormatter(10)],
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Phone number is required';
                                if (v.length != 10) return 'Enter a valid 10-digit number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                  child: Icon(_obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  child: Icon(_obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                ),
                              ),
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _register(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Please confirm your password' : null,
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _register,
                                child: const Text('Create account'),
                              ),
                            ),
                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppTheme.inkMuted,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.pop(),
                                  child: Text(
                                    'Sign in',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  final String message;
  const _ProgressDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 18),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
