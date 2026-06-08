import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
import 'package:local_vyapari_user/shared/widgets/primary_button.dart';

class DisplayNameScreen extends ConsumerStatefulWidget {
  const DisplayNameScreen({super.key});

  @override
  ConsumerState<DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends ConsumerState<DisplayNameScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late bool _needsPhone;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    if (authState is NeedsDisplayName) {
      _nameCtrl.text = authState.suggestedName;
      _nameCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameCtrl.text.length,
      );
      _needsPhone = authState.needsPhone;
    } else {
      _needsPhone = false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();

    if (!_needsPhone) {
      await ref.read(authProvider.notifier).completeProfile(name);
      return;
    }

    final phone = '+91${_phoneCtrl.text.trim()}';
    final notifier = ref.read(authProvider.notifier);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Text('Sending OTP…', style: GoogleFonts.poppins(fontSize: 14)),
          ],
        ),
      ),
    );

    await notifier.sendPhoneOtpForProfileSetup(
      phone,
      onCodeSent: (verificationId) {
        Navigator.pop(context);
        _showOtpDialog(phone: phone, verificationId: verificationId, name: name);
      },
      onFailed: (error) {
        Navigator.pop(context);
        if (mounted) {
          CustomSnackBar.showError(
            context: context,
            message: error,
            title: 'Could not send OTP',
          );
        }
      },
    );
  }

  void _showOtpDialog({
    required String phone,
    required String verificationId,
    required String name,
  }) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final codeCtrl = TextEditingController();
        bool verifying = false;

        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: Text(
                'Verify Phone',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the 6-digit OTP sent to $phone.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
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
                          try {
                            await ref
                                .read(authProvider.notifier)
                                .verifyPhoneForProfileSetup(
                                  verificationId,
                                  codeCtrl.text.trim(),
                                  phone,
                                );
                            if (ctx.mounted) Navigator.pop(dialogCtx, true);
                          } catch (e) {
                            if (ctx.mounted) {
                              setS(() => verifying = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst('Exception: ', ''),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: verifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify & Continue'),
                ),
              ],
            );
          },
        );
      },
    ).then((ok) async {
      if (ok == true && mounted) {
        await ref.read(authProvider.notifier).completeProfile(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);

    final subtitle = _needsPhone
        ? 'We need your name and phone number to get started.'
        : 'What should we call you?';

    final formContent = _FormBody(
      formKey: _formKey,
      nameCtrl: _nameCtrl,
      phoneCtrl: _phoneCtrl,
      needsPhone: _needsPhone,
      isLoading: isLoading,
      onSubmit: _submit,
    );

    Widget body;
    if (Responsive.useNavRail(context)) {
      body = _TabletLayout(form: formContent, subtitle: subtitle);
    } else {
      body = _PortraitLayout(form: formContent, subtitle: subtitle);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: body,
    );
  }
}

// ── Shared form body ──────────────────────────────────────────────────────────

class _FormBody extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final bool needsPhone;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _FormBody({
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.needsPhone,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24, 36, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
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
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your name',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: nameCtrl,
                        autofocus: !needsPhone,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: needsPhone ? TextInputAction.next : TextInputAction.done,
                        onFieldSubmitted: (_) => needsPhone ? null : (isLoading ? null : onSubmit()),
                        decoration: const InputDecoration(
                          hintText: 'Enter your name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Name is required';
                          }
                          if (v.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This name will be visible to shops when you chat or leave reviews.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),

                if (needsPhone) ...[
                  const SizedBox(height: 20),
                  FadeInSlide(
                    delay: const Duration(milliseconds: 300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phone number',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: phoneCtrl,
                          autofocus: true,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => isLoading ? null : onSubmit(),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(10),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            hintText: '10-digit number',
                            prefixIcon: Icon(Icons.phone_outlined),
                            prefixText: '+91 ',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Phone number is required';
                            }
                            if (v.length != 10) {
                              return 'Enter a valid 10-digit number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We\'ll send an OTP to verify your number.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                FadeInSlide(
                  delay: const Duration(milliseconds: 390),
                  child: ScaleOnTap(
                    child: PrimaryButton(
                      label: needsPhone ? 'Continue & Verify' : 'Continue',
                      isLoading: isLoading,
                      onPressed: onSubmit,
                    ),
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

// ── Portrait layout ───────────────────────────────────────────────────────────

class _PortraitLayout extends StatelessWidget {
  final Widget form;
  final String subtitle;
  const _PortraitLayout({required this.form, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.primary,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
              child: Column(
                children: [
                  FadeInSlide(
                    slideOffset: 30,
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 64,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.storefront_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInSlide(
                    delay: const Duration(milliseconds: 100),
                    child: Column(
                      children: [
                        Text(
                          'Almost there!',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
  final String subtitle;
  const _TabletLayout({required this.form, required this.subtitle});

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
                            'Almost there!',
                            style: GoogleFonts.poppins(
                              fontSize: isLarge ? 28 : 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            subtitle,
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
}
