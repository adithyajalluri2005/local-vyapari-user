import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/services/security/social_auth_service.dart';
import 'package:local_vyapari_user/shared/utils/input_sanitizer.dart';
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
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
    try {
      final credential = await signIn();
      if (credential == null) return;
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(
            context: context, message: '$e', title: 'Sign in failed');
      }
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

    final isLoading = ref.watch(authProvider) is AuthLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.primary,
            body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
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
                        fontSize: 22,
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
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24, 28, 24,
                      MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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

                              _ModeToggle(
                                isEmail: _isEmail,
                                onChanged: (v) {
                                  setState(() => _isEmail = v);
                                  ref.read(authProvider.notifier).resetState();
                                },
                                isDark: isDark,
                              ),
                              const SizedBox(height: 18),

                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isEmail
                                    ? TextFormField(
                                        key: const ValueKey('email'),
                                        controller: _emailCtrl,
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
                                        controller: _phoneCtrl,
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
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _passCtrl,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => isLoading ? null : _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(() => _obscure = !_obscure),
                                    child: Icon(_obscure
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
                                  onPressed: () => _showResetDialog(context),
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              PrimaryButton(
                                label: 'Sign in',
                                isLoading: isLoading,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 20),

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
                              OutlinedButton.icon(
                                onPressed: isLoading
                                    ? null
                                    : () => _handleSocial(ref
                                        .read(socialAuthServiceProvider)
                                        .signInWithGoogle),
                                icon: const Icon(Icons.g_mobiledata, size: 28),
                                label: const Text('Continue with Google'),
                              ),
                              if (Platform.isIOS || Platform.isMacOS) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => _handleSocial(ref
                                          .read(socialAuthServiceProvider)
                                          .signInWithApple),
                                  icon: const Icon(Icons.apple, size: 24),
                                  label: const Text('Continue with Apple'),
                                ),
                              ],
                              const SizedBox(height: 20),

                              Row(
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
                                        color: Colors.white,
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
            ),
          ],
        ),
          ),
          if (isLoading)
            Container(
              color: AppColors.primary,
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.storefront_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Signing you in...',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) async {
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
