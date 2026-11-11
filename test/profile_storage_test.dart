import 'dart:convert';

import 'package:daily_bread/data/datasources/profile_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const guest = ProfileId.guest();
  final alice = ProfileId.account('alice');
  final bob = ProfileId.account('bob');

  Future<SharedPreferences> preferences([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPreferences.getInstance();
  }

  test('isolates guest and exact account UIDs, even unusual UIDs', () async {
    final storage = ProfileStorage(await preferences());
    final guestLike = ProfileId.account('guest');
    final unusual = ProfileId.account('a/🚀_b');
    final surrogate = ProfileId.account('\ud800');
    await storage.set(guest, ProfileField.userData, 'guest progress');
    await storage.set(alice, ProfileField.userData, 'alice progress');
    await storage.set(bob, ProfileField.userData, 'bob progress');
    await storage.set(guestLike, ProfileField.userData, 'account progress');
    await storage.set(unusual, ProfileField.userData, 'unicode progress');
    await storage.set(surrogate, ProfileField.userData, 'surrogate progress');
    expect(storage.get(guest, ProfileField.userData), 'guest progress');
    expect(
      storage.get(ProfileId.account('alice'), ProfileField.userData),
      'alice progress',
    );
    expect(storage.get(bob, ProfileField.userData), 'bob progress');
    expect(storage.get(guestLike, ProfileField.userData), 'account progress');
    expect(
      storage.get(ProfileId.account('a/🚀_b'), ProfileField.userData),
      'unicode progress',
    );
    expect(
      storage.get(ProfileId.account('\ufffd'), ProfileField.userData),
      isNull,
    );
    expect(
      storage.get(ProfileId.account('\ud800'), ProfileField.userData),
      'surrogate progress',
    );
    expect(() => ProfileId.account(''), throwsArgumentError);
    await storage.remove(alice, ProfileField.userData);
    expect(storage.get(alice, ProfileField.userData), isNull);
    expect(storage.get(guest, ProfileField.userData), 'guest progress');
  });

  test(
    'migrates every profile key without decoding, removing, or copying device settings',
    () async {
      final legacy = <String, Object>{
        'user_data': '{invalid but retained',
        'active_plan_id': 'plan',
        'active_plan_started_at': '2026-01-01',
        'completed_plan_reward_ids': <String>['one', 'two', 'one'],
        'verse_bookmarks': '[{"note":"test"}]',
        'verse_bookmark_tombstones': '{"verse":"date"}',
        'cloud_sync_snapshot': '{"snapshot":true}',
        'cloud_last_synced_at': 'date',
        'sync_success_count': 4,
        'sync_failure_count': 3,
        'sync_retry_scheduled_count': 2,
        'sync_last_outcome': 'failure',
        'sync_last_outcome_at': 'date',
        'bible_translation': 'web',
        'daily_reminder_enabled': true,
        'daily_reminder_time': '08:30',
      };
      final prefs = await preferences(legacy);
      final storage = ProfileStorage(prefs);
      expect(
        await storage.migrateLegacy(guest),
        LegacyMigrationResult.migrated,
      );
      for (final field in ProfileField.values) {
        expect(
          storage.get(guest, field),
          legacy[field.legacyKey],
          reason: field.legacyKey,
        );
        expect(prefs.get(field.legacyKey), legacy[field.legacyKey]);
        expect(storage.get(alice, field), isNull);
      }
      for (final key in [
        'bible_translation',
        'daily_reminder_enabled',
        'daily_reminder_time',
      ]) {
        expect(prefs.get(key), legacy[key]);
      }
      await storage.set(guest, ProfileField.userData, 'edited');
      expect(
        await storage.migrateLegacy(guest),
        LegacyMigrationResult.alreadyMigrated,
      );
      expect(storage.get(guest, ProfileField.userData), 'edited');
      await expectLater(storage.migrateLegacy(alice), throwsStateError);
      expect(storage.get(alice, ProfileField.userData), isNull);
    },
  );

  test(
    'requires attribution and refuses to mix with an existing profile',
    () async {
      final prefs = await preferences({'user_data': 'unattributed'});
      final storage = ProfileStorage(prefs);
      expect(storage.get(guest, ProfileField.userData), isNull);
      expect(storage.get(alice, ProfileField.userData), isNull);
      await storage.set(alice, ProfileField.bookmarks, 'existing');
      await expectLater(storage.migrateLegacy(alice), throwsStateError);
      expect(storage.get(alice, ProfileField.bookmarks), 'existing');
      expect(prefs.getString('user_data'), 'unattributed');
      expect(
        await storage.migrateLegacy(guest),
        LegacyMigrationResult.migrated,
      );
    },
  );

  test('no legacy data does not reserve an owner', () async {
    final prefs = await preferences({'bible_translation': 'web'});
    final storage = ProfileStorage(prefs);
    expect(
      await storage.migrateLegacy(guest),
      LegacyMigrationResult.noLegacyData,
    );
    await prefs.setString('user_data', 'later');
    expect(await storage.migrateLegacy(alice), LegacyMigrationResult.migrated);
  });

  test(
    'resumes reserved snapshot without mixing or recopying changed legacy',
    () async {
      final prefs = await preferences({
        'user_data': 'changed after reservation',
        'profile_storage_v1_legacy_migration': jsonEncode({
          'owner': 'guest',
          'complete': false,
          'data': {'user_data': 'original'},
        }),
      });
      final storage = ProfileStorage(prefs);
      await expectLater(
        storage.set(guest, ProfileField.bookmarks, 'new'),
        throwsStateError,
      );
      await expectLater(storage.migrateLegacy(alice), throwsStateError);
      expect(
        await storage.migrateLegacy(guest),
        LegacyMigrationResult.migrated,
      );
      expect(storage.get(guest, ProfileField.userData), 'original');
      expect(prefs.getString('user_data'), 'changed after reservation');
    },
  );

  test(
    'resumes after profile copy without overwriting the existing copy',
    () async {
      final prefs = await preferences({
        'profile_storage_v1_legacy_migration': jsonEncode({
          'owner': 'guest',
          'complete': false,
          'data': {'user_data': 'snapshot'},
        }),
        'profile_storage_v1_profile_guest': jsonEncode({
          'data': {'user_data': 'copied'},
          'legacyImport': true,
        }),
      });
      final storage = ProfileStorage(prefs);
      expect(
        await storage.migrateLegacy(guest),
        LegacyMigrationResult.migrated,
      );
      expect(storage.get(guest, ProfileField.userData), 'copied');
      expect(
        await storage.migrateLegacy(guest),
        LegacyMigrationResult.alreadyMigrated,
      );
    },
  );

  test(
    'copies lists and serializes concurrent updates across instances',
    () async {
      final prefs = await preferences();
      final first = ProfileStorage(prefs);
      final second = ProfileStorage(prefs);
      final list = ['a', 'b'];
      await first.set(guest, ProfileField.completedPlanRewardIds, list);
      list.add('caller mutation');
      final retrieved =
          first.get(guest, ProfileField.completedPlanRewardIds) as List<String>;
      retrieved.add('read mutation');
      expect(first.get(guest, ProfileField.completedPlanRewardIds), ['a', 'b']);
      await Future.wait([
        first.set(guest, ProfileField.userData, 'progress'),
        second.set(guest, ProfileField.bookmarks, 'bookmarks'),
      ]);
      expect(first.get(guest, ProfileField.userData), 'progress');
      expect(first.get(guest, ProfileField.bookmarks), 'bookmarks');
      await expectLater(
        first.set(guest, ProfileField.userData, <int>[1]),
        throwsArgumentError,
      );
      await first.set(guest, ProfileField.userData, 'still works');
    },
  );
}
