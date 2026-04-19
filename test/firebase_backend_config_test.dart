import 'package:daily_bread/services/cloud/firebase_backend_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseBackendConfig', () {
    test('reports not configured when core values are missing', () {
      const config = FirebaseBackendConfig(
        apiKey: '',
        projectId: '',
        messagingSenderId: '',
        androidAppId: '',
        iosAppId: '',
        webAppId: '',
        storageBucket: '',
        authDomain: '',
        iosBundleId: '',
      );

      expect(config.hasCoreValues, isFalse);
      expect(config.isConfiguredForPlatform(TargetPlatform.android), isFalse);
      expect(config.optionsForPlatform(TargetPlatform.iOS), isNull);
    });

    test('builds options when platform is configured', () {
      const config = FirebaseBackendConfig(
        apiKey: 'api-key',
        projectId: 'dailybread-prod',
        messagingSenderId: '12345',
        androidAppId: '1:12345:android:abc',
        iosAppId: '1:12345:ios:def',
        webAppId: '',
        storageBucket: 'dailybread.appspot.com',
        authDomain: '',
        iosBundleId: 'com.dailybread.dailyBread',
      );

      final androidOptions = config.optionsForPlatform(TargetPlatform.android);
      final iosOptions = config.optionsForPlatform(TargetPlatform.iOS);

      expect(androidOptions, isNotNull);
      expect(androidOptions!.appId, '1:12345:android:abc');
      expect(iosOptions, isNotNull);
      expect(iosOptions!.appId, '1:12345:ios:def');
      expect(config.isConfiguredForPlatform(TargetPlatform.macOS), isFalse);
    });
  });
}
