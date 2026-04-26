import 'dart:async';

import 'package:daily_bread/presentation/providers/auth_provider.dart';
import 'package:daily_bread/presentation/screens/create_account_screen.dart';
import 'package:daily_bread/presentation/screens/sign_in_screen.dart';
import 'package:daily_bread/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeAuthService implements AuthService {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;
  Object? signInError;
  Object? signUpError;
  Object? resetError;
  int signInCalls = 0;
  int signUpCalls = 0;
  int resetCalls = 0;

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
    _emit(const AuthUser(uid: 'uid-sign-in', email: 'user@example.com', isAnonymous: false));
  }

  @override
  Future<void> signUpWithEmailPassword(String email, String password) async {
    signUpCalls += 1;
    if (signUpError != null) {
      throw signUpError!;
    }
    _emit(const AuthUser(uid: 'uid-sign-up', email: 'new@example.com', isAnonymous: false));
  }

  @override
  Future<void> linkAnonymousWithEmailPassword(
    String email,
    String password,
  ) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetCalls += 1;
    if (resetError != null) {
      throw resetError!;
    }
  }

  @override
  Future<void> signOut() async {
    _emit(null);
  }

  void _emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

Widget _buildTestApp({
  required _FakeAuthService service,
  required Widget home,
}) {
  return ChangeNotifierProvider(
    create: (_) => AuthProvider(service),
    child: MaterialApp(home: home),
  );
}

void main() {
  group('Auth screens', () {
    testWidgets('sign in screen validates email and password', (tester) async {
      final service = _FakeAuthService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        _buildTestApp(service: service, home: const SignInScreen()),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'invalid-email',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        '1234',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Password must be at least 8 characters.'), findsOneWidget);
    });

    testWidgets('create account validates minimum password and confirmation', (
      tester,
    ) async {
      final service = _FakeAuthService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        _buildTestApp(service: service, home: const CreateAccountScreen()),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        '1234567',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'different',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();

      expect(find.text('Password must be at least 8 characters.'), findsOneWidget);
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('sign in submits and pops on success', (tester) async {
      final service = _FakeAuthService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        _buildTestApp(
          service: service,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                      );
                    },
                    child: const Text('Open sign in'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open sign in'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(service.signInCalls, 1);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets('create account submits and pops on success', (tester) async {
      final service = _FakeAuthService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        _buildTestApp(
          service: service,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateAccountScreen(),
                        ),
                      );
                    },
                    child: const Text('Open create account'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open create account'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'password123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(service.signUpCalls, 1);
      expect(find.byType(CreateAccountScreen), findsNothing);
    });

    testWidgets('forgot password sends reset and shows confirmation', (
      tester,
    ) async {
      final service = _FakeAuthService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        _buildTestApp(service: service, home: const SignInScreen()),
      );

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      final dialogEmailField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextFormField, 'Email'),
      );
      await tester.enterText(
        dialogEmailField,
        'user@example.com',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(service.resetCalls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Password reset email sent.'), findsOneWidget);
    });

    testWidgets('sign in shows provider error message', (tester) async {
      final service = _FakeAuthService();
      addTearDown(service.dispose);
      service.signInError = FirebaseAuthException(code: 'wrong-password');

      await tester.pumpWidget(
        _buildTestApp(service: service, home: const SignInScreen()),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
    });
  });
}
