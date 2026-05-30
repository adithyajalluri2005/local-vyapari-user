import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/services/security/account_security_service.dart';
import 'package:local_vyapari_user/services/security/mfa_service.dart';
import 'package:local_vyapari_user/features/security/presentation/screens/mfa_enroll_screen.dart';

/// Account-security hub: two-factor auth, signed-in devices, and
/// "sign out everywhere".
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  List<MultiFactorInfo> _factors = const [];
  bool _loadingFactors = true;

  @override
  void initState() {
    super.initState();
    _loadFactors();
  }

  Future<void> _loadFactors() async {
    setState(() => _loadingFactors = true);
    try {
      final factors = await ref.read(mfaServiceProvider).enrolledFactors();
      if (mounted) setState(() => _factors = factors);
    } catch (_) {
      // ignore — likely offline; section just shows "not enabled".
    } finally {
      if (mounted) setState(() => _loadingFactors = false);
    }
  }

  Future<void> _enrollMfa() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MfaEnrollScreen()),
    );
    if (done == true) _loadFactors();
  }

  Future<void> _unenroll(MultiFactorInfo factor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable two-factor auth?'),
        content: const Text(
            'You may be asked to sign in again. Your account will be less protected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Disable')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(mfaServiceProvider).unenroll(factor.uid);
      await _loadFactors();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication disabled.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not disable. You may need to sign in again first.')),
        );
      }
    }
  }

  Future<void> _signOutEverywhere() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out everywhere?'),
        content: const Text(
            'This signs out all other devices. You will stay signed in here.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out all')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(accountSecurityServiceProvider).signOutEverywhere();
      ref.invalidate(accountDevicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out of all other devices.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not complete. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(accountDevicesProvider);
    final mfaEnabled = _factors.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        children: [
          _sectionHeader(context, 'Two-factor authentication'),
          if (_loadingFactors)
            const ListTile(
                leading: Icon(Icons.security),
                title: Text('Checking status…'))
          else if (mfaEnabled)
            ..._factors.map(
              (f) => ListTile(
                leading: const Icon(Icons.verified_user, color: Colors.green),
                title: Text(f.displayName ?? 'Authenticator app'),
                subtitle: const Text('Enabled'),
                trailing: TextButton(
                  onPressed: () => _unenroll(f),
                  child: const Text('Disable'),
                ),
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Authenticator app (TOTP)'),
              subtitle: const Text('Add a second layer of protection'),
              trailing: FilledButton(
                  onPressed: _enrollMfa, child: const Text('Enable')),
            ),
          const Divider(),
          _sectionHeader(context, 'Signed-in devices'),
          devicesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const ListTile(
              leading: Icon(Icons.error_outline),
              title: Text('Could not load devices'),
            ),
            data: (devices) {
              if (devices.isEmpty) {
                return const ListTile(title: Text('No other devices recorded.'));
              }
              return Column(
                children: [
                  for (final d in devices)
                    ListTile(
                      leading: const Icon(Icons.devices),
                      title: Text(d.userAgent ?? 'Unknown device'),
                      subtitle: Text(
                          d.lastSeen != null ? 'Last active: ${d.lastSeen}' : ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                        onPressed: () async {
                          await ref
                              .read(accountSecurityServiceProvider)
                              .revokeDevice(d.id);
                          ref.invalidate(accountDevicesProvider);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sign out of all other devices'),
              onPressed: _signOutEverywhere,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
