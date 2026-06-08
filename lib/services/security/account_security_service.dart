import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A device that has signed in to the account (from `/known_devices` in RTDB,
/// surfaced by direct database query).
class AccountDevice {
  AccountDevice({
    required this.id,
    required this.userAgent,
    required this.firstSeen,
    required this.lastSeen,
  });

  final String id;
  final String? userAgent;
  final DateTime? firstSeen;
  final DateTime? lastSeen;

  static DateTime? _ts(dynamic v) =>
      v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;

  factory AccountDevice.fromMap(Map<String, dynamic> m) => AccountDevice(
        id: m['id']?.toString() ?? '',
        userAgent: m['userAgent']?.toString(),
        firstSeen: _ts(m['firstSeen']),
        lastSeen: _ts(m['lastSeen']),
      );
}

/// Client wrapper over the device/session-management APIs.
class AccountSecurityService {
  AccountSecurityService(this._functions, this._auth);

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<List<AccountDevice>> listDevices() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    
    final snapshot = await FirebaseDatabase.instance.ref('users_devices/${user.uid}/devices').get();
    if (!snapshot.exists || snapshot.value is! Map) return [];

    final data = snapshot.value as Map;
    final List<AccountDevice> list = [];
    data.forEach((key, val) {
      if (val is Map) {
        if (val['revoked'] != true) {
          list.add(AccountDevice(
            id: val['id']?.toString() ?? key.toString(),
            userAgent: val['userAgent']?.toString() ?? 'Unknown Device',
            firstSeen: AccountDevice._ts(val['firstSeen']),
            lastSeen: AccountDevice._ts(val['lastSeen']),
          ));
        }
      }
    });
    return list;
  }

  Future<void> revokeDevice(String deviceId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await FirebaseDatabase.instance.ref('users_devices/${user.uid}/devices/$deviceId').update({
      'revoked': true,
    });
  }

  Future<void> signOutEverywhere() async {
    await _functions.httpsCallable('signOutEverywhere').call<dynamic>();
    await _auth.currentUser?.getIdToken(true);
  }

  Future<bool> assertRecentAuth({int maxAgeSeconds = 300}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final tokenResult = await user.getIdTokenResult(true);
      final authTime = tokenResult.authTime;
      if (authTime == null) return false;
      final difference = DateTime.now().difference(authTime).inSeconds;
      return difference <= maxAgeSeconds;
    } catch (_) {
      return false;
    }
  }
}

final accountSecurityServiceProvider = Provider<AccountSecurityService>(
  (ref) => AccountSecurityService(
    FirebaseFunctions.instance,
    FirebaseAuth.instance,
  ),
);

final accountDevicesProvider = FutureProvider.autoDispose<List<AccountDevice>>(
  (ref) => ref.watch(accountSecurityServiceProvider).listDevices(),
);
