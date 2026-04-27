import 'dart:async';

import 'package:daily_bread/presentation/providers/auth_provider.dart';
import 'package:daily_bread/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService implements AuthService {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;
  Object? signInError;
  Object? signUpError;
  Object? linkError;
  int signInCalls = 0;
  int signUpCalls = 0;
  int linkCalls = 0;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<void> signInWithEmailPassword(String email, String password) async {
    signInCalls += 1;
    if (signInError != null) {
      throw signInError!;
    }
    emit(
      const AuthUser(
        uid: 'signed-in',
        email: 'user@example.com',
        isAnonymous: false,
      ),
    );
  }

  @override
  Future<void> signUpWithEmailPassword(String email, String password) async {
    signUpCalls += 1;
    if (signUpError != null) {
      throw signUpError!;
    }
    emit(
      const AuthUser(
        uid: 'new-user',
        email: 'new@example.com',
        isAnonymous: false,
      ),
    );
  }

  @override
  Future<void> linkAnonymousWithEmailPassword(
    String email,
    String password,
  ) async {
    linkCalls += 1;
    if (linkError != null) {
      throw linkError!;
    }
    emit(
      AuthUser(
        uid: _currentUser?.uid ?? 'anon-linked',
        email: email,
        isAnonymous: false,
      ),
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async {
    emit(null);
  }

  void emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  group('AuthProvider', () {
    test('reflects auth state updates from service', () async {
      final service = _FakeAuthService();
      final provider = AuthProvider(service);

      expect(provider.isAuthenticated, isFalse);
      expect(provider.currentUser, isNull);

      service.emit(
        const AuthUser(
          uid: '123',
          email: 'user@example.com',
          isAnonymous: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser?.uid, '123');
      expect(provider.isAnonymous, isFalse);

      provider.dispose();
      await service.dispose();
    });

    test('sets friendly message for sign-in auth failure', () async {
      final service = _FakeAuthService();
      service.signInError = FirebaseAuthException(code: 'wrong-password');
      final provider = AuthProvider(service);

      await provider.signInWithEmailPassword('user@example.com', 'wrong');

      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, 'Invalid email or password.');
      expect(provider.isAuthenticated, isFalse);

      provider.dispose();
      await service.dispose();
    });

    test('supports anonymous account linking flow', () async {
      final service = _FakeAuthService();
      service.emit(const AuthUser(uid: 'anon', email: null, isAnonymous: true));
      final provider = AuthProvider(service);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isAnonymous, isTrue);

      await provider.linkAnonymousWithEmailPassword(
        'link@example.com',
        'pass1234',
      );

      expect(provider.errorMessage, isNull);
      expect(provider.currentUser?.uid, 'anon');
      expect(provider.isAnonymous, isFalse);

      provider.dispose();
      await service.dispose();
    });

    test('sign up links anonymous user instead of creating new uid', () async {
      final service = _FakeAuthService();
      service.emit(
        const AuthUser(uid: 'anon-preserved', email: null, isAnonymous: true),
      );
      final provider = AuthProvider(service);
      await Future<void>.delayed(Duration.zero);

      await provider.signUpWithEmailPassword('new@example.com', 'pass1234');

      expect(service.linkCalls, 1);
      expect(service.signUpCalls, 0);
      expect(service.signInCalls, 0);
      expect(provider.errorMessage, isNull);
      expect(provider.currentUser?.uid, 'anon-preserved');
      expect(provider.currentUser?.email, 'new@example.com');
      expect(provider.isAnonymous, isFalse);

      provider.dispose();
      await service.dispose();
    });

    test(
      'sign up falls back to sign in when anonymous link email exists',
      () async {
        final service = _FakeAuthService();
        service.emit(
          const AuthUser(uid: 'anon', email: null, isAnonymous: true),
        );
        service.linkError = FirebaseAuthException(code: 'email-already-in-use');
        final provider = AuthProvider(service);
        await Future<void>.delayed(Duration.zero);

        await provider.signUpWithEmailPassword('user@example.com', 'pass1234');

        expect(service.linkCalls, 1);
        expect(service.signInCalls, 1);
        expect(service.signUpCalls, 0);
        expect(provider.errorMessage, isNull);
        expect(provider.currentUser?.uid, 'signed-in');
        expect(provider.isAnonymous, isFalse);

        provider.dispose();
        await service.dispose();
      },
    );
  });
}
