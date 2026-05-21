import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';

// Provider for FirebaseAuth dependency injection to facilitate unit testing
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<User?>? _authStateSubscription;

  @override
  AuthState build() {
    final auth = ref.watch(firebaseAuthProvider);
    
    _authStateSubscription?.cancel();
    _authStateSubscription = auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        try {
          final roleSnap = await FirebaseDatabase.instance.ref('users').child(user.uid).child('role').get();
          final role = roleSnap.value as String?;
          if (role == 'merchant') {
            await auth.signOut();
            state = const Unauthenticated();
          } else {
            state = Authenticated(user);
          }
        } catch (e) {
          await auth.signOut();
          state = const Unauthenticated();
        }
      } else {
        state = const Unauthenticated();
      }
    });

    ref.onDispose(() {
      _authStateSubscription?.cancel();
    });

    return const AuthInitial();
  }

  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    final auth = ref.read(firebaseAuthProvider);
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      final uid = credential.user?.uid;
      if (uid != null) {
        final roleSnap = await FirebaseDatabase.instance.ref('users').child(uid).child('role').get();
        final role = roleSnap.value as String?;
        if (role == 'merchant') {
          await auth.signOut();
          state = const AuthFailure(
            'Access Denied: This account is registered as a merchant. Please use the Local Vyapari Vendor app.',
          );
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      state = AuthFailure(e.message ?? 'An unknown error occurred during login.');
    } catch (e) {
      state = AuthFailure(e.toString());
    }
  }

  Future<void> register(String email, String password) async {
    state = const AuthLoading();
    final auth = ref.read(firebaseAuthProvider);
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid != null) {
        await FirebaseDatabase.instance.ref('users').child(uid).set({
          'email': email.trim(),
          'role': 'customer',
          'createdAt': ServerValue.timestamp,
        });
      }
    } on FirebaseAuthException catch (e) {
      state = AuthFailure(e.message ?? 'An unknown error occurred during registration.');
    } catch (e) {
      state = AuthFailure(e.toString());
    }
  }

  Future<void> logout() async {
    state = const AuthLoading();
    final auth = ref.read(firebaseAuthProvider);
    try {
      await auth.signOut();
    } catch (e) {
      state = AuthFailure(e.toString());
    }
  }

  void resetState() {
    final auth = ref.read(firebaseAuthProvider);
    if (state is AuthFailure) {
      state = auth.currentUser != null ? Authenticated(auth.currentUser!) : const Unauthenticated();
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
