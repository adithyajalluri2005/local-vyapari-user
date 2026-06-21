import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
import 'package:local_vyapari_user/shared/widgets/primary_button.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final profileData = ref.read(userProfileProvider).value;
    final authState = ref.read(authProvider);
    final user = authState is Authenticated ? authState.user : null;
    final existing = profileData?['displayName']?.toString().trim() ??
        user?.displayName?.trim() ??
        '';
    _nameCtrl.text = existing;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).completeProfile(_nameCtrl.text.trim());
      if (mounted) {
        CustomSnackBar.showSuccess(
          context: context,
          title: 'Saved',
          message: 'Your name has been updated.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(
          context: context,
          title: 'Error',
          message: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = Responsive.isSmallPhone(context);
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            hPad, 24, hPad,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : AppColors.border,
                          width: 0.7,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Display Name',
                            style: GoogleFonts.poppins(
                              fontSize: isSmall ? 11.0 : 12.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _save(),
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Name cannot be empty' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _loading
                        ? const Center(child: CircularProgressIndicator())
                        : PrimaryButton(label: 'Save Changes', onPressed: _save),
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
