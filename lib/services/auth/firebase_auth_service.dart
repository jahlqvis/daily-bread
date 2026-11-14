import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth? _injectedFirebaseAuth;

  FirebaseAuthService({FirebaseAuth? firebaseAuth})
    : _injectedFirebaseAuth = firebaseAuth;

  bool get _isAvailable =>
      _injectedFirebaseAuth != null ||
      Firebase.apps.any((app) => app.name == '[DEFAULT]');

  FirebaseAuth get _firebaseAuth {
    if (!_isAvailable) {
      throw StateError('Account services are unavailable on this device.');
    }
    return _injectedFirebaseAuth ?? FirebaseAuth.instance;
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    if (!_isAvailable) {
      return Stream<AuthUser?>.value(null);
    }
    return _firebaseAuth.userChanges().map(_toAuthUser);
  }

  @override
  AuthUser? get currentUser =>
      _isAvailable ? _toAuthUser(_firebaseAuth.currentUser) : null;

  @override
  Future<void> signInWithEmailPassword(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signUpWithEmailPassword(String email, String password) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> linkAnonymousWithEmailPassword(
    String email,
    String password,
  ) async {
    final current = _firebaseAuth.currentUser;
    if (current == null) {
      throw StateError('No active user to link.');
    }
    if (!current.isAnonymous) {
      throw StateError('Current user is not anonymous.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await current.linkWithCredential(credential);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  AuthUser? _toAuthUser(User? user) {
    if (user == null) {
      return null;
    }

    return AuthUser(
      uid: user.uid,
      email: user.email,
      isAnonymous: user.isAnonymous,
    );
  }
}
