import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  StreamSubscription<AuthUser?>? _authSubscription;

  AuthUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._authService) {
    _currentUser = _authService.currentUser;
    _authSubscription = _authService.authStateChanges().listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  AuthUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isAnonymous => _currentUser?.isAnonymous ?? false;

  Future<void> signInWithEmailPassword(String email, String password) async {
    await _runAuthAction(() => _authService.signInWithEmailPassword(email, password));
  }

  Future<void> signUpWithEmailPassword(String email, String password) async {
    await _runAuthAction(() => _authService.signUpWithEmailPassword(email, password));
  }

  Future<void> linkAnonymousWithEmailPassword(
    String email,
    String password,
  ) async {
    await _runAuthAction(
      () => _authService.linkAnonymousWithEmailPassword(email, password),
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _runAuthAction(() => _authService.sendPasswordResetEmail(email));
  }

  Future<void> signOut() async {
    await _runAuthAction(_authService.signOut);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } on FirebaseAuthException catch (error) {
      _errorMessage = _mapAuthError(error.code);
    } on StateError catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Authentication failed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
