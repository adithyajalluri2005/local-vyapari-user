import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps Firebase Authentication's TOTP (authenticator-app) multi-factor API.
///
/// TOTP is used instead of SMS as the second factor: it costs nothing per use
/// and works offline. Requires the project to be on Identity Platform with TOTP
/// MFA enabled in the console.
class MfaService {
  MfaService(this._auth);

  final FirebaseAuth _auth;

  /// Begins enrollment: returns the shared secret and an `otpauth://` URL the
  /// user can scan as a QR code or add manually to their authenticator app.
  Future<TotpEnrollment> startTotpEnrollment() async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');

    final session = await user.multiFactor.getSession();
    final secret = await TotpMultiFactorGenerator.generateSecret(session);
    final url = await secret.generateQrCodeUrl(
      accountName: user.email ?? user.phoneNumber ?? user.uid,
      issuer: 'Local Vyapari',
    );
    return TotpEnrollment(
        secret: secret, qrCodeUrl: url, sharedSecretKey: secret.secretKey);
  }

  /// Finishes enrollment by verifying the first code from the user's app.
  Future<void> finalizeTotpEnrollment({
    required TotpSecret secret,
    required String code,
    String displayName = 'Authenticator app',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');

    final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(
      secret,
      code.trim(),
    );
    await user.multiFactor.enroll(assertion, displayName: displayName);
  }

  Future<List<MultiFactorInfo>> enrolledFactors() async {
    final user = _auth.currentUser;
    if (user == null) return const [];
    return user.multiFactor.getEnrolledFactors();
  }

  Future<void> unenroll(String factorUid) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    await user.multiFactor.unenroll(factorUid: factorUid);
  }
}

class TotpEnrollment {
  TotpEnrollment({
    required this.secret,
    required this.qrCodeUrl,
    required this.sharedSecretKey,
  });

  final TotpSecret secret;
  final String qrCodeUrl;
  final String sharedSecretKey;
}

final mfaServiceProvider =
    Provider<MfaService>((ref) => MfaService(FirebaseAuth.instance));
