import 'package:daily_bread/data/datasources/profile_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed migration writes reload the cache and retry safely', () async {
    const guest = ProfileId.guest();
    final alice = ProfileId.account('alice');
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    for (final failAt in [1, 2, 3]) {
      final disk = <String, Object>{'flutter.user_data': 'legacy'};
      var writeCount = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getAll') return Map<String, Object>.from(disk);
        if (call.method == 'setString') {
          writeCount++;
          if (writeCount == failAt) return false;
          final args = call.arguments as Map<Object?, Object?>;
          disk[args['key'] as String] = args['value'] as Object;
          return true;
        }
        throw StateError('Unexpected call: ${call.method}');
      });
      SharedPreferences.resetStatic();
      final prefs = await SharedPreferences.getInstance();
      final storage = ProfileStorage(prefs);
      await expectLater(storage.migrateLegacy(guest), throwsStateError);
      expect(prefs.getString('user_data'), 'legacy');
      if (failAt > 1) {
        await expectLater(
          storage.set(guest, ProfileField.userData, 'edited'),
          throwsStateError,
        );
        await expectLater(storage.migrateLegacy(alice), throwsStateError);
      }
      expect(
        await storage.migrateLegacy(guest),
        LegacyMigrationResult.migrated,
      );
      expect(storage.get(guest, ProfileField.userData), 'legacy');
      expect(disk['flutter.user_data'], 'legacy');
      expect(
        await storage.migrateLegacy(guest),
        LegacyMigrationResult.alreadyMigrated,
      );
    }
  });

  test('a failed cache reload blocks reads until a retry reloads', () async {
    const guest = ProfileId.guest();
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final disk = <String, Object>{'flutter.user_data': 'legacy'};
    var failWrite = true;
    var failReload = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') {
        if (failReload) {
          failReload = false;
          throw PlatformException(code: 'reload-failed');
        }
        return Map<String, Object>.from(disk);
      }
      if (call.method == 'setString') {
        if (failWrite) {
          failWrite = false;
          failReload = true;
          return false;
        }
        final args = call.arguments as Map<Object?, Object?>;
        disk[args['key'] as String] = args['value'] as Object;
        return true;
      }
      throw StateError('Unexpected call: ${call.method}');
    });
    SharedPreferences.resetStatic();
    final storage = ProfileStorage(await SharedPreferences.getInstance());
    await expectLater(
      storage.migrateLegacy(guest),
      throwsA(isA<PlatformException>()),
    );
    expect(() => storage.get(guest, ProfileField.userData), throwsStateError);
    expect(await storage.migrateLegacy(guest), LegacyMigrationResult.migrated);
    expect(storage.get(guest, ProfileField.userData), 'legacy');
  });
}
