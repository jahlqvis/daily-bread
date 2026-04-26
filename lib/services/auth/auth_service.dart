class AuthUser {
  final String uid;
  final String? email;
  final bool isAnonymous;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.isAnonymous,
  });
}

abstract class AuthService {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;

  Future<void> signInWithEmailPassword(String email, String password);
  Future<void> signUpWithEmailPassword(String email, String password);
  Future<void> linkAnonymousWithEmailPassword(String email, String password);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();
}
