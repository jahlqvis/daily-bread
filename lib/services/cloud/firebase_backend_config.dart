import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBackendConfig {
  final String apiKey;
  final String projectId;
  final String messagingSenderId;
  final String androidAppId;
  final String iosAppId;
  final String webAppId;
  final String storageBucket;
  final String authDomain;
  final String iosBundleId;

  const FirebaseBackendConfig({
    required this.apiKey,
    required this.projectId,
    required this.messagingSenderId,
    required this.androidAppId,
    required this.iosAppId,
    required this.webAppId,
    required this.storageBucket,
    required this.authDomain,
    required this.iosBundleId,
  });

  factory FirebaseBackendConfig.fromEnvironment() {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    const fallbackAppId = String.fromEnvironment('FIREBASE_APP_ID');

    return FirebaseBackendConfig(
      apiKey: apiKey,
      projectId: projectId,
      messagingSenderId: messagingSenderId,
      androidAppId: const String.fromEnvironment(
        'FIREBASE_ANDROID_APP_ID',
        defaultValue: fallbackAppId,
      ),
      iosAppId: const String.fromEnvironment(
        'FIREBASE_IOS_APP_ID',
        defaultValue: fallbackAppId,
      ),
      webAppId: const String.fromEnvironment(
        'FIREBASE_WEB_APP_ID',
        defaultValue: fallbackAppId,
      ),
      storageBucket: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      authDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
    );
  }

  bool get hasCoreValues {
    return apiKey.isNotEmpty &&
        projectId.isNotEmpty &&
        messagingSenderId.isNotEmpty;
  }

  bool isConfiguredForPlatform(TargetPlatform? platform) {
    if (!hasCoreValues) {
      return false;
    }

    if (kIsWeb) {
      return webAppId.isNotEmpty;
    }

    if (platform == TargetPlatform.iOS) {
      return iosAppId.isNotEmpty;
    }

    if (platform == TargetPlatform.android) {
      return androidAppId.isNotEmpty;
    }

    return false;
  }

  FirebaseOptions? optionsForPlatform(TargetPlatform? platform) {
    if (!isConfiguredForPlatform(platform)) {
      return null;
    }

    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: apiKey,
        appId: webAppId,
        projectId: projectId,
        messagingSenderId: messagingSenderId,
        authDomain: authDomain.isEmpty ? null : authDomain,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
      );
    }

    if (platform == TargetPlatform.iOS) {
      return FirebaseOptions(
        apiKey: apiKey,
        appId: iosAppId,
        projectId: projectId,
        messagingSenderId: messagingSenderId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
        iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
      );
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: androidAppId,
      projectId: projectId,
      messagingSenderId: messagingSenderId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
    );
  }
}
