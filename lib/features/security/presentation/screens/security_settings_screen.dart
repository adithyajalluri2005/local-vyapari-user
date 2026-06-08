import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/services/security/account_security_service.dart';

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
  bool _isSigningOut = false;

  Future<void> _signOutEverywhere() async {
    if (_isSigningOut) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out everywhere?'),
        content: const Text('This signs out all other devices. You will stay signed in here.'),
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
    setState(() => _isSigningOut = true);
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
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(accountDevicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        children: [
          _sectionHeader(context, 'Signed-in devices'),
          devicesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Could not load devices'),
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
                          d.lastSeen != null ? 'Last active: ${d.lastSeen.toString()}' : ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                        onPressed: _isSigningOut
                            ? null
                            : () async {
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
              onPressed: _isSigningOut ? null : _signOutEverywhere,
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
