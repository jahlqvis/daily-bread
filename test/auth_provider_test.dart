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

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<void> signInWithEmailPassword(String email, String password) async {
    if (signInError != null) {
      throw signInError!;
    }
    emit(const AuthUser(uid: 'signed-in', email: 'user@example.com', isAnonymous: false));
  }

  @override
  Future<void> signUpWithEmailPassword(String email, String password) async {
    if (signUpError != null) {
      throw signUpError!;
    }
    emit(const AuthUser(uid: 'new-user', email: 'new@example.com', isAnonymous: false));
  }

  @override
  Future<void> linkAnonymousWithEmailPassword(
    String email,
    String password,
  ) async {
    if (linkError != null) {
      throw linkError!;
    }
    emit(const AuthUser(uid: 'anon-linked', email: 'link@example.com', isAnonymous: false));
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
      service.signInError = FirebaseAuthException(
        code: 'wrong-password',
      );
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
      service.emit(
        const AuthUser(uid: 'anon', email: null, isAnonymous: true),
      );
      final provider = AuthProvider(service);
      await Future<void>.delayed(Duration.zero);

      expect(provider.isAnonymous, isTrue);

      await provider.linkAnonymousWithEmailPassword(
        'link@example.com',
        'pass1234',
      );

      expect(provider.errorMessage, isNull);
      expect(provider.currentUser?.uid, 'anon-linked');
      expect(provider.isAnonymous, isFalse);

      provider.dispose();
      await service.dispose();
    });
  });
}
