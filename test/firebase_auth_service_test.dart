import 'package:daily_bread/presentation/providers/auth_provider.dart';
import 'package:daily_bread/services/auth/firebase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unconfigured Firebase exposes a signed-out state', () async {
    final service = FirebaseAuthService();
    final provider = AuthProvider(service);

    expect(service.currentUser, isNull);
    expect(await service.authStateChanges().first, isNull);
    expect(provider.isAuthenticated, isFalse);

    await provider.signInWithEmailPassword('reader@example.com', 'password');
    expect(
      provider.errorMessage,
      'Account services are unavailable on this device.',
    );
    expect(provider.isAuthenticated, isFalse);

    provider.dispose();
  });
}
