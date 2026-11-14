import 'package:daily_bread/data/datasources/profile_local_data_source.dart';
import 'package:daily_bread/data/datasources/profile_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed profile write is reported and can be retried', () async {
    const channel = MethodChannel('plugins.flutter.io/shared_preferences');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final disk = <String, Object>{'flutter.active_plan_id': 'legacy'};
    var fail = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getAll') return Map<String, Object>.from(disk);
      if (call.method == 'setString') {
        if (fail) {
          fail = false;
          return false;
        }
        final args = call.arguments as Map<Object?, Object?>;
        disk[args['key'] as String] = args['value'] as Object;
        return true;
      }
      throw StateError('Unexpected call: ${call.method}');
    });
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final source = ProfileLocalDataSource(prefs, const ProfileId.guest());
    await expectLater(source.saveActivePlanId('new'), throwsStateError);
    expect(source.getActivePlanId(), isNull);
    expect(prefs.getString('active_plan_id'), 'legacy');
    await source.saveActivePlanId('new');
    expect(source.getActivePlanId(), 'new');
  });
}
