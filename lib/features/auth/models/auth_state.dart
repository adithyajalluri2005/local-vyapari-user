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

class NeedsDisplayName extends AuthState {
  final User user;
  final String suggestedName;
  final bool needsPhone;
  const NeedsDisplayName(this.user, this.suggestedName, {this.needsPhone = false});
}

