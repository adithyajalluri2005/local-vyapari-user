import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/services/role_service.dart';
import 'package:local_vyapari_user/services/notifications/notification_service.dart';

const _phoneEmailStorage = FlutterSecureStorage();
const _phoneEmailCachePrefix = 'lv_phone_email_';

// Providers for Firebase dependencies to facilitate testing overrides
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});

final roleServiceProvider = Provider<RoleService>((ref) {
  return RoleService.instance;
});

final sessionValidationProvider = Provider<Future<bool> Function(User, String)>((ref) {
  return (user, targetRole) async {
    bool roleConfirmed = false;

    // Fast path: check JWT custom claims (no network if token < 1 hour old)
    try {
      final tokenResult = await user.getIdTokenResult(false);
      final rolesClaim = tokenResult.claims?['roles'];
      if (rolesClaim is Map && rolesClaim.isNotEmpty) {
        roleConfirmed = rolesClaim[targetRole] == true;
        // Claims present — trust them, skip RTDB read
        if (!roleConfirmed) return false;
      }
    } catch (_) {}

    // Slow path: fall back to RTDB (first login or claims not set)
    if (!roleConfirmed) {
      try {
        final snapshot = await ref.read(firebaseDatabaseProvider)
            .ref('users/${user.uid}/roles')
            .get();
        if (snapshot.exists && snapshot.value is Map) {
          final roles = snapshot.value as Map;
          roleConfirmed = roles[targetRole] == true;
        }
      } catch (_) {
        return false;
      }
    }

    if (roleConfirmed) {
      // Fire-and-forget device registration — does not need to block sign-in
      ref.read(firebaseDatabaseProvider)
          .ref('users_devices/${user.uid}/devices/client_device')
          .update({
        'id': 'client_device',
        'userAgent': 'Flutter Customer Client',
        'lastSeen': ServerValue.timestamp,
        'revoked': false,
      });
    }
    return roleConfirmed;
  };
});

class AuthLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setLoading(bool val) => state = val;
}
final authLoadingProvider = NotifierProvider<AuthLoadingNotifier, bool>(AuthLoadingNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<User?>? _authStateSubscription;
  // When we sign out because a user failed role validation or an error occurred,
  // the authStateChanges stream fires null and would overwrite our AuthFailure
  // state with Unauthenticated before the UI can show the error. This flag
  // suppresses that one null emission.
  bool _suppressNextSignOutTransition = false;

  FirebaseDatabase get _rtdb => ref.read(firebaseDatabaseProvider);
  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);
  FirebaseFunctions get _functions => ref.read(firebaseFunctionsProvider);

  @override
  AuthState build() {
    _authStateSubscription?.cancel();
    final auth = ref.watch(firebaseAuthProvider);
    
    _authStateSubscription = auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        try {
          final isCustomer = await isCustomerUser(user);
          if (isCustomer) {
            // Google sign-in users must provide display name + phone on first sign-in.
            final isGoogleUser = user.providerData.any((p) => p.providerId == 'google.com');
            if (isGoogleUser) {
              final results = await Future.wait([
                _rtdb.ref('users/${user.uid}/displayName').get(),
                _rtdb.ref('users/${user.uid}/phone').get(),
              ]);
              final savedName = results[0].value?.toString().trim() ?? '';
              final savedPhone = results[1].value?.toString().trim() ?? '';
              if (savedName.isEmpty || savedPhone.isEmpty) {
                state = NeedsDisplayName(
                  user,
                  user.displayName ?? '',
                  needsPhone: savedPhone.isEmpty,
                );
                return;
              }
            }
            state = Authenticated(user);
            // Lazily initialise notifications now that the user is authenticated
            ref.read(notificationServiceProvider);
          } else {
            _suppressNextSignOutTransition = true;
            await auth.signOut();
            state = const AuthFailure('Access Denied: Unauthorized role.');
          }
        } catch (e) {
          _suppressNextSignOutTransition = true;
          await auth.signOut();
          state = AuthFailure(e.toString());
        }
      } else {
        // Always clear sensitive cache on every sign-out.
        await DataCacheService.clearCache();
        // If we triggered this sign-out ourselves after setting an AuthFailure,
        // don't overwrite that error with Unauthenticated.
        if (_suppressNextSignOutTransition) {
          _suppressNextSignOutTransition = false;
          return;
        }
        state = const Unauthenticated();
      }
    });

    ref.onDispose(() {
      _authStateSubscription?.cancel();
    });

    return const AuthInitial();
  }

  Future<bool> isCustomerUser(User user) async {
    return ref.read(sessionValidationProvider)(user, 'customer');
  }

  Future<void> completeProfile(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    ref.read(authLoadingProvider.notifier).setLoading(true);
    try {
      final name = displayName.trim();
      await Future.wait([
        user.updateDisplayName(name),
        _rtdb.ref('users/${user.uid}').update({
          'displayName': name,
          'email': user.email ?? '',
          'createdAt': ServerValue.timestamp,
        }),
      ]);
      state = Authenticated(user);
      ref.read(notificationServiceProvider);
    } catch (e) {
      state = AuthFailure(e.toString());
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> isPhoneRegistered(String phone) async {
    final snapshot = await _rtdb.ref('phones').child(phone).get();
    return snapshot.exists && snapshot.value != null;
  }

  Future<String> resolveLoginEmailForPhone(String phone) async {
    final result = await _functions.httpsCallable('resolvePhoneLoginEmail').call({
      'phone': phone,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final email = data['email']?.toString();
    if (email == null || email.isEmpty) {
      throw Exception('No email found linked to this phone number.');
    }
    return email;
  }

  Future<void> sendFirebaseOtp({
    required String phone,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException e) onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final user = _auth.currentUser;
          if (user != null) {
            await user.linkWithCredential(credential);
            await _rtdb.ref('users').child(user.uid).update({
              'phone': phone,
              'verified': true,
            });
            await _rtdb.ref('phones').child(phone).set(user.uid);
          } else {
            await _auth.signInWithCredential(credential);
          }
        } catch (e) {
          // Auto-verification is best-effort, but a failure here can leave the
          // 'phones' index / 'verified' flag out of sync — surface it for debugging.
          debugPrint('Phone auto-verification post-link write failed: $e');
        }
      },
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> verifyAndSignInWithPhone(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> verifyAndLinkPhone(String verificationId, String smsCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    await user.linkWithCredential(credential);

    final phone = user.phoneNumber ?? '';
    if (phone.isNotEmpty) {
      await _rtdb.ref('users').child(user.uid).update({
        'phone': phone,
        'verified': true,
      });
      await _rtdb.ref('phones').child(phone).set(user.uid);
    }
  }

  Future<void> bindEmail(String email) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");
    
    await _rtdb.ref('users').child(uid).child('email').set(email.trim());
    
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(email.trim());
    } catch (e) {
      debugPrint("Firebase Auth email update: $e");
    }
  }

  String mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'This email address is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Authentication error. Please try again.';
    }
  }

  String mapFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'invalid-argument':
        return e.message ?? 'Invalid request.';
      case 'resource-exhausted':
        return e.message ?? 'Too many attempts. Please try again later.';
      case 'not-found':
        return e.message ?? 'Requested record was not found.';
      case 'failed-precondition':
        return e.message ?? 'This action cannot be completed right now.';
      case 'unavailable':
        return e.message ?? 'OTP delivery is unavailable right now. Please try again later.';
      case 'internal':
        return e.message ?? 'OTP delivery failed. Please try again later.';
      case 'permission-denied':
        return e.message ?? 'Access denied for this account.';
      default:
        return e.message ?? 'Request failed. Please try again.';
    }
  }

  Future<bool> login(String email, String password) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    state = const AuthLoading();
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      // Role validation is handled by the authStateChanges listener which fires
      // immediately after sign-in — no need to call isCustomerUser here.
      return credential.user != null;
    } on FirebaseAuthException catch (e) {
      state = AuthFailure(mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthFailure(e.toString());
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> loginWithPhoneAndPassword(String phone, String password) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    state = const AuthLoading();
    try {
      final formattedPhone = phone.trim();

      // Use cached email to skip the Cloud Function round-trip on repeat logins
      String? realEmail = await _phoneEmailStorage.read(
          key: '$_phoneEmailCachePrefix$formattedPhone');
      if (realEmail == null || realEmail.isEmpty) {
        realEmail = await resolveLoginEmailForPhone(formattedPhone);
        _phoneEmailStorage.write(
            key: '$_phoneEmailCachePrefix$formattedPhone', value: realEmail);
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: realEmail,
        password: password.trim(),
      );
      // Role validation is handled by the authStateChanges listener.
      return credential.user != null;
    } on FirebaseAuthException catch (e) {
      state = AuthFailure(mapFirebaseError(e));
      return false;
    } on FirebaseFunctionsException catch (e) {
      // Invalidate cache on function error in case the cached email is stale
      _phoneEmailStorage.delete(key: '$_phoneEmailCachePrefix${phone.trim()}');
      state = AuthFailure(mapFunctionsError(e));
      return false;
    } catch (e) {
      state = AuthFailure(e.toString());
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> register(String email, String password, {String? phone}) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    state = const AuthLoading();
    try {
      if (phone != null && phone.isNotEmpty) {
        final formattedPhone = phone.trim();
        final isPhoneReg = await isPhoneRegistered(formattedPhone);
        if (isPhoneReg) {
          state = const AuthFailure(
            'This phone number is already registered. If you registered this number for your merchant account, please log in with your password.',
          );
          return false;
        }
      }
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final uid = credential.user?.uid;
      if (uid != null) {
        final updates = {
          'email': email.trim(),
          'createdAt': ServerValue.timestamp,
        };
        if (phone != null && phone.isNotEmpty) {
          updates['phone'] = phone.trim();
          updates['verified'] = true;
        }
        await _rtdb.ref('users').child(uid).update(updates);
        if (phone != null && phone.isNotEmpty) {
          await _rtdb.ref('phones').child(phone.trim()).set(uid);
        }
      }
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthFailure(mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthFailure(e.toString());
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> checkPhone(String phone) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    try {
      final isRegistered = await isPhoneRegistered(phone);
      return isRegistered;
    } catch (e) {
      state = AuthFailure(e.toString());
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> requestOtp(
    String phone, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    try {
      await sendFirebaseOtp(
        phone: phone,
        onCodeSent: (verificationId, _) {
          onCodeSent(verificationId);
        },
        onFailed: (e) {
          state = AuthFailure(e.message ?? 'Verification failed');
          onFailed(e.message ?? 'Verification failed');
        },
      );
      return true;
    } catch (e) {
      state = AuthFailure(e.toString());
      onFailed(e.toString());
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> verifyAndSubmit({
    required String verificationId,
    required String code,
    required bool isRegistered,
    String? phone,
  }) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    state = const AuthLoading();
    try {
      if (isRegistered) {
        await verifyAndSignInWithPhone(verificationId, code);
      } else {
        final credential = await verifyAndSignInWithPhone(verificationId, code);
        final user = credential.user;
        if (user != null) {
          final phoneNum = phone ?? user.phoneNumber ?? '';
          final email = '${phoneNum.replaceAll('+', '')}@localvyapari.com';

          await _rtdb.ref('users').child(user.uid).update({
            'email': email,
            'phone': phoneNum,
            'createdAt': ServerValue.timestamp,
            'verified': true,
          });

          await _rtdb.ref('phones').child(phoneNum).set(user.uid);
        }
      }
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthFailure(mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthFailure(e.toString());
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> requestBindPhoneOtp(
    String phone, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");
      
      final formattedPhone = phone.trim();
      
      final existingUidSnapshot = await _rtdb.ref('phones').child(formattedPhone).get();
      if (existingUidSnapshot.exists && existingUidSnapshot.value != uid) {
        throw Exception("This phone number is already linked to another account");
      }
      
      await sendFirebaseOtp(
        phone: formattedPhone,
        onCodeSent: (verificationId, _) {
          onCodeSent(verificationId);
        },
        onFailed: (e) {
          state = AuthFailure(e.message ?? 'Verification failed');
          onFailed(e.message ?? 'Verification failed');
        },
      );
      return true;
    } catch (e) {
      state = AuthFailure(e.toString().replaceFirst('Exception: ', ''));
      onFailed(e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> requestPasswordResetOtp(
    String phone, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    try {
      final formattedPhone = phone.trim();
      final isReg = await isPhoneRegistered(formattedPhone);
      if (!isReg) {
        state = const AuthFailure('This phone number is not registered');
        onFailed('This phone number is not registered');
        return false;
      }
      await sendFirebaseOtp(
        phone: formattedPhone,
        onCodeSent: (verificationId, _) {
          onCodeSent(verificationId);
        },
        onFailed: (e) {
          state = AuthFailure(e.message ?? 'Verification failed');
          onFailed(e.message ?? 'Verification failed');
        },
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthFailure(mapFirebaseError(e));
      onFailed(mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthFailure(e.toString().replaceFirst('Exception: ', ''));
      onFailed(e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> verifyAndBindPhone(String verificationId, String code) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    try {
      await verifyAndLinkPhone(verificationId, code);
      return true;
    } catch (e) {
      state = AuthFailure(e.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> resetPasswordWithPhoneOtp({
    required String verificationId,
    required String code,
    required String newPassword,
  }) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    state = const AuthLoading();
    try {
      final credential = await verifyAndSignInWithPhone(verificationId, code);
      final user = credential.user;
      if (user == null) {
        throw Exception("Failed to authenticate user via phone OTP");
      }
      await user.updatePassword(newPassword);
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthFailure(mapFirebaseError(e));
      return false;
    } catch (e) {
      state = AuthFailure(e.toString());
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> sendRegistrationOtp(
    String phone, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    try {
      final formattedPhone = phone.trim();
      final isReg = await isPhoneRegistered(formattedPhone);
      if (isReg) {
        state = const AuthFailure('This phone number is already registered. If you registered this number for your merchant account, please log in with your password.');
        onFailed('This phone number is already registered. If you registered this number for your merchant account, please log in with your password.');
        return false;
      }
      await sendFirebaseOtp(
        phone: formattedPhone,
        onCodeSent: (verificationId, _) {
          onCodeSent(verificationId);
        },
        onFailed: (e) {
          state = AuthFailure(e.message ?? 'Verification failed');
          onFailed(e.message ?? 'Verification failed');
        },
      );
      return true;
    } catch (e) {
      state = AuthFailure(e.toString());
      onFailed(e.toString());
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<bool> registerWithPhoneOtp({
    required String verificationId,
    required String code,
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    state = const AuthLoading();
    try {
      final credential = await verifyAndSignInWithPhone(verificationId, code);
      final user = credential.user;
      if (user == null) {
        throw Exception("Failed to authenticate user via phone OTP");
      }

      final emailCred = EmailAuthProvider.credential(
        email: email.trim(),
        password: password.trim(),
      );
      await user.linkWithCredential(emailCred);

      final uid = user.uid;
      final trimmedName = name.trim();
      if (trimmedName.isNotEmpty) {
        await user.updateDisplayName(trimmedName);
      }
      final updates = {
        'displayName': trimmedName,
        'email': email.trim(),
        'phone': phone.trim(),
        'verified': true,
        'createdAt': ServerValue.timestamp,
      };
      await _rtdb.ref('users').child(uid).update(updates);
      await _rtdb.ref('phones').child(phone.trim()).set(uid);
      
      return true;
    } on FirebaseAuthException catch (e) {
      await _auth.signOut();
      state = AuthFailure(mapFirebaseError(e));
      return false;
    } catch (e) {
      await _auth.signOut();
      state = AuthFailure(e.toString());
      return false;
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  // ── Profile-setup helpers for Google sign-in users ──────────────────────────
  // These do NOT touch auth state on failure — the caller shows errors locally
  // so the NeedsDisplayName flow stays intact.

  Future<void> sendPhoneOtpForProfileSetup(
    String phone, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('User not signed in');

      final existing = await _rtdb.ref('phones').child(phone).get();
      if (existing.exists && existing.value != uid) {
        onFailed('This phone number is already linked to another account');
        return;
      }

      await sendFirebaseOtp(
        phone: phone,
        onCodeSent: (verificationId, _) => onCodeSent(verificationId),
        onFailed: (e) => onFailed(e.message ?? 'Verification failed'),
      );
    } catch (e) {
      onFailed(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<void> verifyPhoneForProfileSetup(
    String verificationId,
    String smsCode,
    String phone,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not signed in');

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      // Already linked to this account → treat as success and continue saving.
      if (e.code != 'credential-already-in-use' && e.code != 'provider-already-linked') {
        rethrow;
      }
    }

    await _rtdb.ref('users/${user.uid}').update({
      'phone': phone,
      'verified': true,
    });
    await _rtdb.ref('phones').child(phone).set(user.uid);
  }

  Future<void> logout() async {
    ref.read(authLoadingProvider.notifier).setLoading(true);
    try {
      await _auth.signOut();
    } catch (e) {
      state = AuthFailure(e.toString());
    } finally {
      ref.read(authLoadingProvider.notifier).setLoading(false);
    }
  }

  void resetState() {
    if (state is AuthFailure) {
      state = _auth.currentUser != null ? Authenticated(_auth.currentUser!) : const Unauthenticated();
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is! Authenticated) return Stream.value(null);
  final user = authState.user;
  
  return FirebaseDatabase.instance
      .ref('users')
      .child(user.uid)
      .onValue
      .map((event) {
        if (event.snapshot.value == null) return null;
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      });
});
