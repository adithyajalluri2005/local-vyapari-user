import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:local_vyapari_user/services/security/social_auth_service.dart';
import 'package:local_vyapari_user/shared/utils/input_sanitizer.dart';
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isEmail = true;
  bool _socialLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final pw = _passCtrl.text;
    final pwErr = InputSanitizer.validatePassword(pw);
    if (pwErr != null) {
      CustomSnackBar.showError(context: context, message: pwErr, title: 'Validation Error');
      return;
    }

    if (_isEmail) {
      final email = _emailCtrl.text.trim();
      final emailErr = InputSanitizer.validateEmail(email);
      if (emailErr != null) {
        CustomSnackBar.showError(context: context, message: emailErr, title: 'Validation Error');
        return;
      }
      await ref.read(authProvider.notifier).login(email, pw);
    } else {
      final phone = _phoneCtrl.text.trim();
      if (phone.length != 10) {
        CustomSnackBar.showError(
          context: context,
          message: 'Enter a valid 10-digit number',
          title: 'Validation Error',
        );
        return;
      }
      await ref.read(authProvider.notifier).loginWithPhoneAndPassword('+91$phone', pw);
    }
  }

  Future<void> _handleSocial(Future<UserCredential?> Function() signIn) async {
    setState(() => _socialLoading = true);
    try {
      final credential = await signIn();
      if (credential == null) {
        setState(() => _socialLoading = false);
        return;
      }
    } catch (e) {
      setState(() => _socialLoading = false);
      if (mounted) {
        CustomSnackBar.showError(
            context: context, message: '$e', title: 'Sign in failed');
      }
    }
  }

  void _showResetDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetDialog(ref: ref),
    );
    if (ok == true && context.mounted) {
      CustomSnackBar.showSuccess(
        context: context,
        title: 'Password reset',
        message: 'Your password has been reset successfully.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthFailure) {
        CustomSnackBar.showError(context: context, message: next.message, title: 'Sign in failed');
        ref.read(authProvider.notifier).resetState();
      }
    });

    final isLoading = ref.watch(authProvider) is AuthLoading || _socialLoading;

    final formContent = _FormBody(
      formKey: _formKey,
      emailCtrl: _emailCtrl,
      phoneCtrl: _phoneCtrl,
      passCtrl: _passCtrl,
      obscure: _obscure,
      isEmail: _isEmail,
      isLoading: isLoading,
      onObscureChanged: (v) => setState(() => _obscure = v),
      onModeChanged: (v) {
        setState(() => _isEmail = v);
        ref.read(authProvider.notifier).resetState();
      },
      onSubmit: _submit,
      onForgotPassword: _showResetDialog,
      onGoogleSignIn: () => _handleSocial(ref.read(socialAuthServiceProvider).signInWithGoogle),
      onAppleSignIn: (Platform.isIOS || Platform.isMacOS)
          ? () => _handleSocial(ref.read(socialAuthServiceProvider).signInWithApple)
          : null,
    );

    Widget body;
    if (Responsive.useNavRail(context)) {
      body = _TabletLayout(form: formContent);
    } else {
      body = _PortraitLayout(form: formContent);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: body,
    );
  }
}

// ── Portrait layout ───────────────────────────────────────────────────────────

class _PortraitLayout extends StatelessWidget {
  final Widget form;
  const _PortraitLayout({required this.form});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = Responsive.isSmallPhone(context);

    return Scaffold(
      backgroundColor: AppColors.primary,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              child: FadeInSlide(
                slideOffset: 30,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 72,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.storefront_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Local Vyapari',
                      style: GoogleFonts.poppins(
                        fontSize: isSmall ? 19 : 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer Portal',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Discover local shops & exclusive offers',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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
                value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                child: form,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tablet layout ─────────────────────────────────────────────────────────────

class _TabletLayout extends StatelessWidget {
  final Widget form;
  const _TabletLayout({required this.form});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLarge = Responsive.isLargeTablet(context);
    final leftWidth = isLarge ? 380.0 : 320.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Row(
        children: [
          SizedBox(
            width: leftWidth,
            child: Container(
              color: AppColors.primary,
              child: SafeArea(
                child: Column(
                  children: [
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
                            errorBuilder: (_, _, _) => Icon(
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
          Expanded(
            child: Container(
              color: isDark ? AppColors.darkScaffold : AppColors.background,
              child: form,
            ),
          ),
        ],
      ),
    );
  }
}// ── Shared form body ──────────────────────────────────────────────────────────

class _FormBody extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final bool isEmail;
  final bool isLoading;
  final ValueChanged<bool> onObscureChanged;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;
  final VoidCallback? onAppleSignIn;

  const _FormBody({
    required this.formKey,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.isEmail,
    required this.isLoading,
    required this.onObscureChanged,
    required this.onModeChanged,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24, 28, 24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeInSlide(
                  delay: const Duration(milliseconds: 150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to continue',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                FadeInSlide(
                  delay: const Duration(milliseconds: 250),
                  child: _ModeToggle(
                    isEmail: isEmail,
                    onChanged: onModeChanged,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 18),
                FadeInSlide(
                  delay: const Duration(milliseconds: 350),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isEmail
                        ? TextFormField(
                            key: const ValueKey('email'),
                            controller: emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Email is required' : null,
                          )
                        : TextFormField(
                            key: const ValueKey('phone'),
                            controller: phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              prefixIcon: Icon(Icons.phone_outlined),
                              prefixText: '+91 ',
                            ),
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [LengthLimitingTextInputFormatter(10)],
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Phone is required';
                              if (v.length != 10) return 'Enter a valid 10-digit number';
                              return null;
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeInSlide(
                  delay: const Duration(milliseconds: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: passCtrl,
                        obscureText: obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => isLoading ? null : onSubmit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: GestureDetector(
                            onTap: () => onObscureChanged(!obscure),
                            child: Icon(obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Password is required' : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onForgotPassword,
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                FadeInSlide(
                  delay: const Duration(milliseconds: 530),
                  child: ScaleOnTap(
                    child: PrimaryButton(
                      label: 'Sign in',
                      isLoading: isLoading,
                      onPressed: onSubmit,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeInSlide(
                  delay: const Duration(milliseconds: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('or continue with',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: AppColors.textHint)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ScaleOnTap(
                        child: OutlinedButton.icon(
                          onPressed: isLoading ? null : onGoogleSignIn,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue with Google'),
                        ),
                      ),
                      if (onAppleSignIn != null) ...[
                        const SizedBox(height: 10),
                        ScaleOnTap(
                          child: OutlinedButton.icon(
                            onPressed: isLoading ? null : onAppleSignIn,
                            icon: const Icon(Icons.apple, size: 24),
                            label: const Text('Continue with Apple'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FadeInSlide(
                  delay: const Duration(milliseconds: 700),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ── Mode toggle ──────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final bool isEmail;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  const _ModeToggle({required this.isEmail, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkElevated : AppColors.surfaceElevated;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.border,
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          _Tab(label: 'Email', active: isEmail, onTap: () => onChanged(true)),
          _Tab(label: 'Phone', active: !isEmail, onTap: () => onChanged(false)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.textHint,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reset dialog ─────────────────────────────────────────────────────────────

class _ResetDialog extends StatefulWidget {
  final WidgetRef ref;
  const _ResetDialog({required this.ref});

  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  final _form = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) return;
    setState(() => _loading = true);
    await widget.ref.read(authProvider.notifier).requestPasswordResetOtp(
      '+91$phone',
      onCodeSent: (id) {
        if (mounted) setState(() { _loading = false; _otpSent = true; _verificationId = id; });
      },
      onFailed: (e) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  void _reset() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await widget.ref.read(authProvider.notifier).resetPasswordWithPhoneOtp(
      verificationId: _verificationId!,
      code: _otpCtrl.text.trim(),
      newPassword: _passCtrl.text.trim(),
    );
    if (mounted) {
      setState(() => _loading = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Reset Password',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixText: '+91 ',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                readOnly: _otpSent,
                inputFormatters: [LengthLimitingTextInputFormatter(10)],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length != 10) return 'Enter 10 digits';
                  return null;
                },
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _otpCtrl,
                  decoration: const InputDecoration(
                    labelText: '6-digit OTP',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [LengthLimitingTextInputFormatter(6)],
                  validator: (v) {
                    if (v == null || v.length != 6) return 'Enter 6-digit OTP';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : (_otpSent ? _reset : _sendOtp),
          child: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_otpSent ? 'Reset' : 'Send OTP'),
        ),
      ],
    );
  }
}
