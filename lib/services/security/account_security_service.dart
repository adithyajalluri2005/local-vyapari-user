import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A device that has signed in to the account (from `/known_devices` in RTDB,
/// surfaced by the `listMyDevices` callable).
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

/// Client wrapper over the device/session-management Cloud Functions.
class AccountSecurityService {
  AccountSecurityService(this._functions, this._auth);

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<List<AccountDevice>> listDevices() async {
    final res = await _functions.httpsCallable('listMyDevices').call<dynamic>();
    final data = Map<String, dynamic>.from(res.data as Map);
    final list = (data['devices'] as List?) ?? const [];
    return list
        .map((e) => AccountDevice.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> revokeDevice(String deviceId) async {
    await _functions
        .httpsCallable('revokeDevice')
        .call<dynamic>({'deviceId': deviceId});
  }

  Future<void> signOutEverywhere() async {
    await _functions.httpsCallable('signOutEverywhere').call<dynamic>();
    await _auth.currentUser?.getIdToken(true);
  }

  Future<bool> assertRecentAuth({int maxAgeSeconds = 300}) async {
    try {
      final res = await _functions
          .httpsCallable('assertRecentAuth')
          .call<dynamic>({'maxAgeSeconds': maxAgeSeconds});
      final data = Map<String, dynamic>.from(res.data as Map);
      return data['ok'] == true;
    } on FirebaseFunctionsException {
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
