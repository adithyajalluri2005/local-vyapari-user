import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/shared/utils/input_sanitizer.dart';
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
import 'package:local_vyapari_user/shared/widgets/primary_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final phone = '+91${_phoneCtrl.text.trim()}';
    final password = _passCtrl.text;

    final emailErr = InputSanitizer.validateEmail(email);
    if (emailErr != null) {
      CustomSnackBar.showError(context: context, message: emailErr, title: 'Validation Error');
      return;
    }
    if (_phoneCtrl.text.trim().length != 10) {
      CustomSnackBar.showError(
        context: context,
        message: 'Enter a valid 10-digit phone number',
        title: 'Validation Error',
      );
      return;
    }
    final passErr = InputSanitizer.validatePassword(password);
    if (passErr != null) {
      CustomSnackBar.showError(context: context, message: passErr, title: 'Validation Error');
      return;
    }
    if (password != _confirmCtrl.text) {
      CustomSnackBar.showError(
        context: context,
        message: 'Passwords do not match',
        title: 'Validation Error',
      );
      return;
    }

    final notifier = ref.read(authProvider.notifier);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Text('Sending OTP…', style: GoogleFonts.poppins(fontSize: 14)),
          ],
        ),
      ),
    );

    await notifier.sendRegistrationOtp(
      phone,
      onCodeSent: (verificationId) {
        Navigator.pop(context);
        showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            final codeCtrl = TextEditingController();
            bool verifying = false;
            return StatefulBuilder(
              builder: (ctx, setS) => AlertDialog(
                title: Text('Verify Phone',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the 6-digit OTP sent to $phone.',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: codeCtrl,
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
                    onPressed: verifying ? null : () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: verifying
                        ? null
                        : () async {
                            if (codeCtrl.text.trim().length != 6) return;
                            setS(() => verifying = true);
                            final ok = await notifier.registerWithPhoneOtp(
                              verificationId: verificationId,
                              code: codeCtrl.text.trim(),
                              email: email,
                              password: password,
                              phone: phone,
                            );
                            if (ctx.mounted) {
                              setS(() => verifying = false);
                              Navigator.pop(dialogCtx, ok);
                            }
                          },
                    child: verifying
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verify & Create'),
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
            builder: (dialogCtx) => AlertDialog(
              title: Text('Account exists',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: Text(
                'This phone is already registered. Sign in with your password.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    context.pop();
                  },
                  child: const Text('Sign in'),
                ),
              ],
            ),
          );
        } else {
          CustomSnackBar.showError(
              context: context, message: error, title: 'OTP Failed');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthFailure) {
        CustomSnackBar.showError(
            context: context, message: next.message, title: 'Registration failed');
        ref.read(authProvider.notifier).resetState();
      }
    });

    final formContent = _FormBody(
      formKey: _formKey,
      emailCtrl: _emailCtrl,
      phoneCtrl: _phoneCtrl,
      passCtrl: _passCtrl,
      confirmCtrl: _confirmCtrl,
      onSubmit: _register,
      onSignIn: () => context.pop(),
    );

    if (Responsive.isTablet(context)) {
      return _TabletLayout(onBack: () => context.pop(), form: formContent);
    }
    return _PortraitLayout(onBack: () => context.pop(), form: formContent);
  }
}

// ── Shared form body (StatefulWidget for password toggle state) ───────────────

class _FormBody extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final VoidCallback onSubmit;
  final VoidCallback onSignIn;

  const _FormBody({
    required this.formKey,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.onSubmit,
    required this.onSignIn,
  });

  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = Responsive.isSmallPhone(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24, 24, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: widget.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Get started',
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 19 : 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create your Local Vyapari account',
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 12 : 13,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: widget.emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Email is required' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: widget.phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixText: '+91 ',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Phone is required';
                    if (v.length != 10) return 'Enter 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: widget.passCtrl,
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscurePass = !_obscurePass),
                      child: Icon(_obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password is required' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: widget.confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => widget.onSubmit(),
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      child: Icon(_obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Please confirm password' : null,
                ),
                const SizedBox(height: 24),

                PrimaryButton(label: 'Create Account', onPressed: widget.onSubmit),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: widget.onSignIn,
                      child: Text(
                        'Sign in',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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
    );
  }
}

// ── Layout 1: Portrait phone ──────────────────────────────────────────────────
// Navy header (back + title) + white rounded sheet

class _PortraitLayout extends StatelessWidget {
  final VoidCallback onBack;
  final Widget form;
  const _PortraitLayout({required this.onBack, required this.form});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = Responsive.isSmallPhone(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Row(
                  children: [
                    _BackButton(onTap: onBack),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Create Account',
                          style: GoogleFonts.poppins(
                            fontSize: isSmall ? 17 : 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Customer Portal',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkScaffold : AppColors.background,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: isDark
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark,
                  child: form,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Layout 2: Tablet (portrait) ───────────────────────────────────────────────
// Left fixed-width navy brand panel | Right scrollable form

class _TabletLayout extends StatelessWidget {
  final VoidCallback onBack;
  final Widget form;
  const _TabletLayout({required this.onBack, required this.form});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLarge = Responsive.isLargeTablet(context);
    final leftWidth = isLarge ? 380.0 : 320.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Row(
          children: [
            // Left: navy brand panel
            SizedBox(
              width: leftWidth,
              child: Container(
                color: AppColors.primary,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _BackButton(onTap: onBack),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: isLarge ? 80 : 64,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.storefront_rounded,
                                size: isLarge ? 64 : 52,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Local Vyapari',
                              style: GoogleFonts.poppins(
                                fontSize: isLarge ? 28 : 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                'Customer Portal',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Discover local shops & exclusive offers near you.',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                color: Colors.white.withValues(alpha: 0.65),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              width: 0.7,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppColors.border,
            ),

            // Right: form panel
            Expanded(
              child: Container(
                color: isDark ? AppColors.darkScaffold : AppColors.background,
                child: form,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared back button ────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 17),
      ),
    );
  }
}
