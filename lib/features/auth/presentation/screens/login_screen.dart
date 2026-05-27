import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
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
      CustomSnackBar.showError(
        context: context,
        message: passwordError,
        title: 'Validation Error',
      );
      return;
    }

    if (_isEmailMode) {
      final email = _emailController.text.trim();
      final emailError = InputSanitizer.validateEmail(email);
      if (emailError != null) {
        CustomSnackBar.showError(
          context: context,
          message: emailError,
          title: 'Validation Error',
        );
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
        CustomSnackBar.showError(
          context: context,
          message: next.message,
          title: 'Authentication Failed',
        );
        ref.read(authProvider.notifier).resetState();
      }
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;
    final padding = AppSizes.paddingLarge(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: AppSizes.paddingMedium(context)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: Responsive.isTablet(context) ? 140 : 100,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.storefront,
                          size: 80,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingLarge(context)),
                    Text(
                      'Welcome Back!',
                      style: AppTextStyles.titleLarge(context, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Login to discover nearby offers',
                      style: AppTextStyles.bodyLarge(context, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppSizes.paddingExtraLarge(context)),
                    
                    // Toggle Tabs for Email/Phone
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (!_isEmailMode) {
                                  setState(() => _isEmailMode = true);
                                  ref.read(authProvider.notifier).resetState();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isEmailMode ? AppTheme.primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Email Address',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _isEmailMode ? Colors.white : Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (_isEmailMode) {
                                  setState(() => _isEmailMode = false);
                                  ref.read(authProvider.notifier).resetState();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isEmailMode ? AppTheme.primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Phone Number',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: !_isEmailMode ? Colors.white : Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Inputs
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isEmailMode
                          ? TextFormField(
                              key: const ValueKey('email_field'),
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Email is required';
                                return null;
                              },
                            )
                          : TextFormField(
                              key: const ValueKey('phone_field'),
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone_android),
                                prefixText: '+91 ',
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Phone number is required';
                                if (val.length != 10) return 'Enter a valid 10-digit number';
                                return null;
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Password is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Login'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final resetSuccess = await showDialog<bool>(
                              context: context,
                              builder: (_) => _ResetPasswordDialog(ref: ref),
                            );
                            if (resetSuccess == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password reset successfully! You can now log in.'),
                                  backgroundColor: AppTheme.successColor,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: const Text('Forgot Password?'),
                        ),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          child: Text(
                            'Sign Up',
                            style: AppTextStyles.titleSmall(context, color: AppTheme.primaryColor),
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
    );
  }
}

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
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Invalid Number'),
          content: const Text('Please enter a valid 10-digit number'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final fullPhone = '+91$phone';
    await widget.ref.read(authProvider.notifier).requestPasswordResetOtp(
      fullPhone,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _otpSent = true;
            _verificationId = verificationId;
          });
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('OTP Sent'),
              content: const Text('OTP sent successfully. Please check your messages.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      onFailed: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Error'),
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  void _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _otpController.text.trim();
    final newPassword = _passwordController.text.trim();

    setState(() => _isLoading = true);

    final success = await widget.ref.read(authProvider.notifier).resetPasswordWithPhoneOtp(
      verificationId: _verificationId!,
      code: code,
      newPassword: newPassword,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        final error = widget.ref.read(authProvider);
        String errorMsg = 'Password reset failed';
        if (error is AuthFailure) {
          errorMsg = error.message;
        }
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.errorColor),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Registered Phone Number',
                  prefixIcon: Icon(Icons.phone_android),
                  prefixText: '+91 ',
                ),
                keyboardType: TextInputType.phone,
                readOnly: _otpSent,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Phone number is required';
                  if (val.length != 10) return 'Enter a valid 10-digit number';
                  return null;
                },
              ),
              if (_otpSent) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: '6-Digit OTP',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'OTP is required';
                    if (val.length != 6) return 'OTP must be 6 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'New password is required';
                    if (val.length < 6) return 'At least 6 characters required';
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
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_otpSent ? 'Reset Password' : 'Send OTP'),
        ),
      ],
    );
  }
}
