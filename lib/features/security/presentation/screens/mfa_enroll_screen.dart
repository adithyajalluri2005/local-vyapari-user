import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/services/security/mfa_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Walks the user through enrolling an authenticator-app (TOTP) second factor:
/// show QR + secret, then verify the first code.
class MfaEnrollScreen extends ConsumerStatefulWidget {
  const MfaEnrollScreen({super.key});

  @override
  ConsumerState<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends ConsumerState<MfaEnrollScreen> {
  final _codeController = TextEditingController();
  TotpEnrollment? _enrollment;
  bool _loading = true;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final enrollment =
          await ref.read(mfaServiceProvider).startTotpEnrollment();
      if (mounted) setState(() => _enrollment = enrollment);
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final enrollment = _enrollment;
    if (enrollment == null) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code shown in your app.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(mfaServiceProvider).finalizeTotpEnrollment(
            secret: enrollment.secret,
            code: code,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Two-factor authentication enabled.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _error = _friendly(e);
        });
      }
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('requires-recent-login')) {
      return 'Please sign out and sign back in, then try enabling 2FA again.';
    }
    if (s.contains('invalid-verification-code') || s.contains('invalid')) {
      return 'That code was incorrect. Check your app and try again.';
    }
    return 'Could not enable 2FA. $s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enrollment = _enrollment;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up two-factor auth')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : enrollment == null
                ? _errorState(theme)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('1. Scan this QR code',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Open Google Authenticator, Authy, or any TOTP app and scan the code below.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.white,
                            child: QrImageView(
                              data: enrollment.qrCodeUrl,
                              size: 200,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Or enter this key manually:',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        SelectableText(
                          enrollment.sharedSecretKey,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(letterSpacing: 1.5),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: enrollment.sharedSecretKey));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Key copied.')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy key'),
                        ),
                        const Divider(height: 32),
                        Text('2. Enter the 6-digit code',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, letterSpacing: 6),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: OutlineInputBorder(),
                            hintText: '000000',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!,
                              style: TextStyle(color: theme.colorScheme.error)),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _verifying ? null : _verify,
                          child: _verifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Verify & enable'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _errorState(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _start, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
