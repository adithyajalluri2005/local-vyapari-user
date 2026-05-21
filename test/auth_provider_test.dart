import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';

// Fake implementations for testing without Firebase SDK dependency
class FakeUser implements User {
  @override
  final String uid;
  @override
  final String? email;
  
  FakeUser({required this.uid, this.email});
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #uid) return uid;
    if (invocation.memberName == #email) return email;
    return super.noSuchMethod(invocation);
  }
}

class FakeUserCredential implements UserCredential {
  @override
  final User? user;
  
  FakeUserCredential(this.user);
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebaseAuth implements FirebaseAuth {
  final _authStateController = StreamController<User?>.broadcast();
  User? _currentUser;
  bool shouldThrowException = false;
  String exceptionMessage = 'Authentication failed';

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _authStateController.stream;

  void emitUserState(User? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (shouldThrowException) {
      throw FirebaseAuthException(code: 'auth-error', message: exceptionMessage);
    }
    final user = FakeUser(uid: 'test_uid', email: email);
    emitUserState(user);
    return FakeUserCredential(user);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (shouldThrowException) {
      throw FirebaseAuthException(code: 'auth-error', message: exceptionMessage);
    }
    final user = FakeUser(uid: 'test_uid', email: email);
    emitUserState(user);
    return FakeUserCredential(user);
  }

  @override
  Future<void> signOut() async {
    emitUserState(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseAuth fakeAuth;
  late ProviderContainer container;

  setUp(() {
    fakeAuth = FakeFirebaseAuth();
    container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(fakeAuth),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('Initial state is AuthInitial, then Unauthenticated on stream bind', () async {
    final stateList = <AuthState>[];
    container.listen<AuthState>(authProvider, (previous, next) {
      stateList.add(next);
    }, fireImmediately: true);

    expect(stateList.first, isA<AuthInitial>());

    // Emit null state to indicate no user is logged in
    fakeAuth.emitUserState(null);
    await Future.delayed(Duration.zero);

    expect(stateList.last, isA<Unauthenticated>());
  });

  test('Successful login transitions through AuthLoading and Authenticated', () async {
    final stateList = <AuthState>[];
    
    // Start listening
    container.listen<AuthState>(authProvider, (previous, next) {
      stateList.add(next);
    }, fireImmediately: true);

    fakeAuth.emitUserState(null);
    await Future.delayed(Duration.zero);

    final loginFuture = container.read(authProvider.notifier).login('test@example.com', 'password123');
    
    // Check state list has entered loading state
    expect(stateList.any((s) => s is AuthLoading), isTrue);

    await loginFuture;
    await Future.delayed(Duration.zero);

    // Final state should be Authenticated
    expect(container.read(authProvider), isA<Authenticated>());
    final authenticatedState = container.read(authProvider) as Authenticated;
    expect(authenticatedState.user.email, 'test@example.com');
  });

  test('Failed login transitions through AuthLoading and AuthFailure', () async {
    final stateList = <AuthState>[];
    
    container.listen<AuthState>(authProvider, (previous, next) {
      stateList.add(next);
    }, fireImmediately: true);

    fakeAuth.emitUserState(null);
    await Future.delayed(Duration.zero);

    fakeAuth.shouldThrowException = true;
    fakeAuth.exceptionMessage = 'Invalid credentials';

    await container.read(authProvider.notifier).login('bad@example.com', 'wrongpassword');
    await Future.delayed(Duration.zero);

    expect(container.read(authProvider), isA<AuthFailure>());
    final failureState = container.read(authProvider) as AuthFailure;
    expect(failureState.message, 'Invalid credentials');
  });

  test('Successful registration transitions to Authenticated', () async {
    fakeAuth.emitUserState(null);
    await Future.delayed(Duration.zero);

    await container.read(authProvider.notifier).register('new@example.com', 'securepass');
    await Future.delayed(Duration.zero);

    expect(container.read(authProvider), isA<Authenticated>());
    final authenticatedState = container.read(authProvider) as Authenticated;
    expect(authenticatedState.user.email, 'new@example.com');
  });

  test('Logout transitions state to Unauthenticated', () async {
    fakeAuth.emitUserState(FakeUser(uid: 'active_user', email: 'user@example.com'));
    await Future.delayed(Duration.zero);

    expect(container.read(authProvider), isA<Authenticated>());

    await container.read(authProvider.notifier).logout();
    await Future.delayed(Duration.zero);

    expect(container.read(authProvider), isA<Unauthenticated>());
  });
}
