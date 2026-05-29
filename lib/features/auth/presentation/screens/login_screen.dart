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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isEmailMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text;
    final passwordError = InputSanitizer.validatePassword(password);
    if (passwordError != null) {
      CustomSnackBar.showError(context: context, message: passwordError, title: 'Validation Error');
      return;
    }

    if (_isEmailMode) {
      final email = _emailController.text.trim();
      final emailError = InputSanitizer.validateEmail(email);
      if (emailError != null) {
        CustomSnackBar.showError(context: context, message: emailError, title: 'Validation Error');
        return;
      }
      await ref.read(authProvider.notifier).login(email, password);
    } else {
      final phone = _phoneController.text.trim();
      if (phone.length != 10) {
        CustomSnackBar.showError(
          context: context,
          message: 'Please enter a valid 10-digit phone number',
          title: 'Validation Error',
        );
        return;
      }
      await ref.read(authProvider.notifier).loginWithPhoneAndPassword('+91$phone', password);
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthFailure) {
        CustomSnackBar.showError(context: context, message: next.message, title: 'Authentication Failed');
        ref.read(authProvider.notifier).resetState();
      }
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;
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
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: Responsive.isTablet(context) ? 90 : 68,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Welcome back',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.isTablet(context) ? 30 : 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to discover deals near you',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
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
                            // ── Mode toggle ──────────────────────────
                            _ModeToggle(
                              isEmailMode: _isEmailMode,
                              onChanged: (v) {
                                setState(() => _isEmailMode = v);
                                ref.read(authProvider.notifier).resetState();
                              },
                            ),
                            const SizedBox(height: 20),

                            // ── Identifier field ─────────────────────
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _isEmailMode
                                  ? TextFormField(
                                      key: const ValueKey('email'),
                                      controller: _emailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email address',
                                        prefixIcon: Icon(Icons.mail_outline_rounded),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
                                    )
                                  : TextFormField(
                                      key: const ValueKey('phone'),
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
                            ),
                            const SizedBox(height: 14),

                            // ── Password field ───────────────────────
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => isLoading ? null : _login(),
                              validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                            ),

                            // ── Forgot password ──────────────────────
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => _ResetPasswordDialog(ref: ref),
                                  );
                                  if (ok == true && context.mounted) {
                                    CustomSnackBar.showSuccess(
                                      context: context,
                                      title: 'Password reset',
                                      message: 'Your password has been reset. You can now log in.',
                                    );
                                  }
                                },
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            // ── CTA ──────────────────────────────────
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _login,
                                child: isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text('Sign in'),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Sign-up link ─────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppTheme.inkMuted,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/register'),
                                  child: Text(
                                    'Create one',
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

class _ModeToggle extends StatelessWidget {
  final bool isEmailMode;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.isEmailMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurfaceMuted : AppTheme.surfaceMuted;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _Pill(label: 'Email', active: isEmailMode, onTap: () => onChanged(true)),
          _Pill(label: 'Phone', active: !isEmailMode, onTap: () => onChanged(false)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppTheme.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reset password dialog — logic unchanged, UI refreshed
// ─────────────────────────────────────────────────────────────────────────────

class _ResetPasswordDialog extends StatefulWidget {
  final WidgetRef ref;
  const _ResetPasswordDialog({required this.ref});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit number')),
      );
      return;
    }
    setState(() => _isLoading = true);
    await widget.ref.read(authProvider.notifier).requestPasswordResetOtp(
      '+91$phone',
      onCodeSent: (id) {
        if (mounted) setState(() { _isLoading = false; _otpSent = true; _verificationId = id; });
      },
      onFailed: (err) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  void _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final ok = await widget.ref.read(authProvider.notifier).resetPasswordWithPhoneOtp(
      verificationId: _verificationId!,
      code: _otpController.text.trim(),
      newPassword: _passwordController.text.trim(),
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Reset Password',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Registered phone number',
                  prefixText: '+91 ',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                readOnly: _otpSent,
                inputFormatters: [LengthLimitingTextInputFormatter(10)],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Phone number is required';
                  if (v.length != 10) return 'Enter a valid 10-digit number';
                  return null;
                },
              ),
              if (_otpSent) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: '6-digit OTP',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [LengthLimitingTextInputFormatter(6)],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'OTP is required';
                    if (v.length != 6) return 'OTP must be 6 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'At least 6 characters required';
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
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : (_otpSent ? _resetPassword : _sendOtp),
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_otpSent ? 'Reset password' : 'Send OTP'),
        ),
      ],
    );
  }
}
