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
      CustomSnackBar.showError(
        context: context,
        message: emailError,
        title: 'Validation Error',
      );
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
      CustomSnackBar.showError(
        context: context,
        message: passwordError,
        title: 'Validation Error',
      );
      return;
    }

    if (password != confirmPassword) {
      CustomSnackBar.showError(
        context: context,
        message: 'Passwords do not match!',
        title: 'Validation Error',
      );
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);

    // Show request loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Requesting verification..."),
          ],
        ),
      ),
    );

    await authNotifier.sendRegistrationOtp(
      phone,
      onCodeSent: (verificationId) {
        // Dismiss requesting dialog
        Navigator.pop(context);

        // Show OTP verification dialog
        showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final codeController = TextEditingController();
            bool isVerifying = false;

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Verify Phone Number'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('We have sent a verification OTP to $phone.'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: '6-Digit OTP',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: isVerifying ? null : () => Navigator.pop(dialogContext, null),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: isVerifying ? null : () async {
                        final code = codeController.text.trim();
                        if (code.length != 6) return;

                        setState(() => isVerifying = true);

                        final regSuccess = await authNotifier.registerWithPhoneOtp(
                          verificationId: verificationId,
                          code: code,
                          email: email,
                          password: password,
                          phone: phone,
                        );

                        if (context.mounted) {
                          setState(() => isVerifying = false);
                          Navigator.pop(dialogContext, regSuccess);
                        }
                      },
                      child: isVerifying
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Verify & Register'),
                    ),
                  ],
                );
              },
            );
          },
        ).then((verified) {
          if (verified == null) {
            CustomSnackBar.showError(
              context: context,
              message: 'Verification canceled',
              title: 'Canceled',
            );
          }
        });
      },
      onFailed: (error) {
        // Dismiss requesting dialog
        Navigator.pop(context);

        CustomSnackBar.showError(
          context: context,
          message: error,
          title: 'OTP Request Failed',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthFailure) {
        CustomSnackBar.showError(
          context: context,
          message: next.message,
          title: 'Registration Failed',
        );
        ref.read(authProvider.notifier).resetState();
      }
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;
    final padding = AppSizes.paddingLarge(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Account',
          style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
        ),
      ),
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
                          Icons.person_add_alt_1,
                          size: 80,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingLarge(context)),
                    Text(
                      'Join Local Vyapari',
                      style: AppTextStyles.titleLarge(context, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign up to discover nearby offers',
                      style: AppTextStyles.bodyLarge(context, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppSizes.paddingExtraLarge(context)),
                    TextFormField(
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
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Confirm Password is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : _register,
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Sign Up'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text(
                        'Already have an account? Login',
                        style: AppTextStyles.titleSmall(context, color: AppTheme.primaryColor),
                      ),
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
