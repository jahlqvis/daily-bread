import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/user_model.dart';
import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:daily_bread/presentation/providers/app_services_provider.dart';
import 'package:daily_bread/services/cloud/cloud_sync_service.dart';
import 'package:daily_bread/services/notifications/daily_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppServicesProvider', () {
    test('syncNow persists snapshot timestamp', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocalDataSource(prefs);

      final provider = AppServicesProvider(
        LocalCloudSyncService(localDataSource),
        LocalReminderService(localDataSource),
      );

      await provider.syncNow(
        user: UserModel(currentStreak: 3, totalXp: 120),
        bookmarks: [
          VerseBookmark(
            book: 'John',
            chapter: 3,
            verse: 16,
            translationId: 'web',
            createdAt: DateTime(2026, 4, 18),
          ),
        ],
      );

      expect(provider.lastSyncedAt, isNotNull);
      expect(localDataSource.getCloudSnapshot(), isNotNull);
      expect(localDataSource.getCloudLastSyncedAt(), isNotNull);
    });

    test('reminder settings are persisted and reloaded', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final localDataSource = LocalDataSource(prefs);

      final provider = AppServicesProvider(
        LocalCloudSyncService(localDataSource),
        LocalReminderService(localDataSource),
      );

      await provider.setReminderEnabled(true);
      await provider.setReminderTime('07:30');

      final reloaded = AppServicesProvider(
        LocalCloudSyncService(localDataSource),
        LocalReminderService(localDataSource),
      );

      expect(reloaded.reminderEnabled, isTrue);
      expect(reloaded.reminderTime, '07:30');
      expect(reloaded.reminderSupported, isFalse);
    });
  });
}
