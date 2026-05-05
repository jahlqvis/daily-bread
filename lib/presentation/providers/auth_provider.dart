import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth/auth_service.dart';

abstract class AuthTelemetry {
  void record(String event, Map<String, Object?> metadata);
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final AuthTelemetry? _authTelemetry;
  StreamSubscription<AuthUser?>? _authSubscription;

  AuthUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._authService, {AuthTelemetry? authTelemetry})
    : _authTelemetry = authTelemetry {
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
  String get diagnosticsAuthState {
    if (!isAuthenticated) {
      return 'signed_out';
    }
    if (isAnonymous) {
      return 'anonymous';
    }
    return 'authenticated';
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    await _runAuthAction(
      () => _authService.signInWithEmailPassword(email, password),
      successEvent: 'auth_sign_in_success',
      failureEvent: 'auth_sign_in_failure',
      metadata: _authMetadata(action: 'sign_in'),
    );
  }

  Future<void> signUpWithEmailPassword(String email, String password) async {
    if (!isAnonymous) {
      await _runAuthAction(
        () => _authService.signUpWithEmailPassword(email, password),
        successEvent: 'auth_sign_up_success',
        failureEvent: 'auth_sign_up_failure',
        metadata: _authMetadata(action: 'sign_up'),
      );
      return;
    }

    await _runAuthAction(() async {
      try {
        await _authService.linkAnonymousWithEmailPassword(email, password);
        _recordTelemetry(
          'auth_link_success',
          _authMetadata(action: 'link', method: 'email_password'),
        );
      } on FirebaseAuthException catch (error) {
        _recordTelemetry(
          'auth_link_failure',
          _authMetadata(
            action: 'link',
            method: 'email_password',
            errorCode: error.code,
          ),
        );
        if (_isCredentialAlreadyInUse(error.code)) {
          await _runAuthAction(
            () => _authService.signInWithEmailPassword(email, password),
            successEvent: 'auth_sign_in_success',
            failureEvent: 'auth_sign_in_failure',
            metadata: _authMetadata(action: 'sign_in_fallback'),
            wrapLoadingState: false,
          );
          return;
        }
        rethrow;
      }
    }, wrapLoadingState: true);
  }

  Future<void> linkAnonymousWithEmailPassword(
    String email,
    String password,
  ) async {
    await _runAuthAction(
      () => _authService.linkAnonymousWithEmailPassword(email, password),
      successEvent: 'auth_link_success',
      failureEvent: 'auth_link_failure',
      metadata: _authMetadata(action: 'link'),
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _runAuthAction(
      () => _authService.sendPasswordResetEmail(email),
      successEvent: 'auth_password_reset_requested',
      failureEvent: 'auth_password_reset_failure',
      metadata: _authMetadata(action: 'password_reset'),
    );
  }

  Future<void> signOut() async {
    await _runAuthAction(
      _authService.signOut,
      successEvent: 'auth_sign_out',
      failureEvent: 'auth_sign_out_failure',
      metadata: _authMetadata(action: 'sign_out'),
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _runAuthAction(
    Future<void> Function() action, {
    String? successEvent,
    String? failureEvent,
    Map<String, Object?> metadata = const <String, Object?>{},
    bool wrapLoadingState = true,
  }) async {
    if (wrapLoadingState) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      await action();
      if (successEvent != null) {
        _recordTelemetry(successEvent, metadata);
      }
    } on FirebaseAuthException catch (error) {
      if (failureEvent != null) {
        _recordTelemetry(
          failureEvent,
          _metadataWithError(metadata, error.code),
        );
      }
      _errorMessage = _mapAuthError(error.code);
    } on StateError catch (error) {
      if (failureEvent != null) {
        _recordTelemetry(
          failureEvent,
          _metadataWithError(metadata, 'state-error'),
        );
      }
      _errorMessage = error.message;
    } catch (_) {
      if (failureEvent != null) {
        _recordTelemetry(failureEvent, _metadataWithError(metadata, 'unknown'));
      }
      _errorMessage = 'Authentication failed. Please try again.';
    } finally {
      if (wrapLoadingState) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Map<String, Object?> _metadataWithError(
    Map<String, Object?> metadata,
    String errorCode,
  ) {
    return <String, Object?>{...metadata, 'errorCode': errorCode};
  }

  Map<String, Object?> _authMetadata({
    required String action,
    String method = 'email_password',
    String? errorCode,
  }) {
    final metadata = <String, Object?>{
      'action': action,
      'method': method,
      'authState': diagnosticsAuthState,
      'errorCode': errorCode,
    };
    metadata.removeWhere((_, value) => value == null);
    return metadata;
  }

  void _recordTelemetry(String event, Map<String, Object?> metadata) {
    _authTelemetry?.record(event, metadata);
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

  bool _isCredentialAlreadyInUse(String code) {
    return code == 'email-already-in-use' ||
        code == 'credential-already-in-use' ||
        code == 'account-exists-with-different-credential';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
