import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/services/role_service.dart';
import 'package:local_vyapari_user/services/notifications/notification_service.dart';

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
    try {
      final result = await ref.read(firebaseFunctionsProvider).httpsCallable('validateSession').call({
        'targetRole': targetRole,
        'deviceInfo': {
          'platform': 'flutter-client',
        }
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['success'] == true) {
        await user.getIdToken(true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
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
            state = Authenticated(user);
            // Lazily initialise notifications now that the user is authenticated
            ref.read(notificationServiceProvider);
          } else {
            await auth.signOut();
            state = const AuthFailure('Access Denied: Unauthorized role.');
          }
        } catch (e) {
          await auth.signOut();
          state = AuthFailure(e.toString());
        }
      } else {
        // Clear sensitive cache when signing out/unauthenticated
        await DataCacheService.clearCache();
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
      final realEmail = await resolveLoginEmailForPhone(formattedPhone);
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
      final updates = {
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
