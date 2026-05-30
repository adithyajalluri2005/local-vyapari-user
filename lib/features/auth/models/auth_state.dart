import 'package:firebase_auth/firebase_auth.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final User user;
  const Authenticated(this.user);
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
}

/// Emitted when a sign-in needs a second factor (TOTP). The login screen
/// watches for this and routes to the MFA challenge screen.
class AuthMfaRequired extends AuthState {
  final MultiFactorResolver resolver;
  const AuthMfaRequired(this.resolver);
}
