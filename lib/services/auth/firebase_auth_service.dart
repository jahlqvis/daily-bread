import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_toAuthUser);
  }

  @override
  AuthUser? get currentUser => _toAuthUser(_firebaseAuth.currentUser);

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

    return AuthUser(uid: user.uid, email: user.email, isAnonymous: user.isAnonymous);
  }
}
