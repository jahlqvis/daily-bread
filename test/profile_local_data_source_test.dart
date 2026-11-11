import 'dart:convert';

import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/datasources/profile_local_data_source.dart';
import 'package:daily_bread/data/datasources/profile_storage.dart';
import 'package:daily_bread/data/models/user_model.dart';
import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:daily_bread/data/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const guest = ProfileId.guest();
  final alice = ProfileId.account('alice');
  final bob = ProfileId.account('bob');

  Future<SharedPreferences> preferences([
    Map<String, Object> values = const {},
  ]) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('repositories persist reading progress to their own profiles', () async {
    final prefs = await preferences();
    final guestSource = ProfileLocalDataSource(prefs, guest);
    final accountSource = ProfileLocalDataSource(prefs, alice);
    final guestRepository = UserRepository(guestSource);
    final accountRepository = UserRepository(accountSource);

    await Future.wait([
      guestRepository.markChapterAsRead('Genesis', 1),
      accountRepository.markChapterAsRead('John', 1),
    ]);

    expect((await guestRepository.getUser()).readingProgress, {
      'Genesis': {1},
    });
    expect((await accountRepository.getUser()).readingProgress, {
      'John': {1},
    });
    expect((await LocalDataSource(prefs).getUser()).readingProgress, isEmpty);
  });

  test(
    'all profile fields round-trip, remain isolated and survive reload',
    () async {
      final prefs = await preferences({
        'user_data': jsonEncode({'totalXp': 999}),
      });
      final legacy = LocalDataSource(prefs);
      final source = ProfileLocalDataSource(prefs, alice);
      final other = ProfileLocalDataSource(prefs, bob);
      final guestSource = ProfileLocalDataSource(prefs, guest);
      final date = DateTime.utc(2026, 5, 1, 9, 30);
      final bookmark = VerseBookmark(
        book: 'John',
        chapter: 3,
        verse: 16,
        translationId: 'web',
        note: 'note',
        createdAt: date,
        updatedAt: date.add(const Duration(hours: 1)),
      );
      expect((await source.getUser()).totalXp, 0);
      expect(source.getActivePlanId(), isNull);
      expect(source.getActivePlanStartedAt(), isNull);
      expect(source.getCompletedPlanRewardIds(), isEmpty);
      expect(source.getBookmarks(), isEmpty);
      expect(source.getBookmarkTombstones(), isEmpty);
      expect(source.getCloudSnapshot(), isNull);
      expect(source.getCloudLastSyncedAt(), isNull);
      expect(source.getSyncSuccessCount(), 0);
      expect(source.getSyncFailureCount(), 0);
      expect(source.getSyncRetryScheduledCount(), 0);
      expect(source.getSyncLastOutcome(), isNull);
      expect(source.getSyncLastOutcomeAt(), isNull);

      await Future.wait([
        source.saveUser(
          UserModel(
            totalXp: 42,
            readingProgress: {
              'John': {3},
            },
          ),
        ),
        source.saveActivePlanId('plan'),
        source.saveActivePlanStartedAt(date),
        source.saveCompletedPlanRewardIds({'plan', 'other'}),
        source.saveBookmarks([bookmark]),
        source.saveBookmarkTombstones({bookmark.id: date}),
        source.saveCloudSnapshot('{"snapshot":true}'),
        source.saveCloudLastSyncedAt(date),
        source.saveSyncSuccessCount(1),
        source.saveSyncFailureCount(2),
        source.saveSyncRetryScheduledCount(3),
        source.saveSyncLastOutcome('failure'),
        source.saveSyncLastOutcomeAt(date),
        other.saveUser(UserModel(totalXp: 7)),
        guestSource.saveUser(UserModel(totalXp: 8)),
      ]);
      await prefs.reload();
      final restored = ProfileLocalDataSource(
        prefs,
        ProfileId.account('alice'),
      );
      expect((await restored.getUser()).totalXp, 42);
      expect((await restored.getUser()).readingProgress, {
        'John': {3},
      });
      expect(restored.getActivePlanId(), 'plan');
      expect(restored.getActivePlanStartedAt(), date);
      expect(restored.getCompletedPlanRewardIds(), {'plan', 'other'});
      expect(restored.getBookmarks().single.toJson(), bookmark.toJson());
      expect(restored.getBookmarkTombstones(), {bookmark.id: date});
      expect(restored.getCloudSnapshot(), '{"snapshot":true}');
      expect(restored.getCloudLastSyncedAt(), date);
      expect(restored.getSyncSuccessCount(), 1);
      expect(restored.getSyncFailureCount(), 2);
      expect(restored.getSyncRetryScheduledCount(), 3);
      expect(restored.getSyncLastOutcome(), 'failure');
      expect(restored.getSyncLastOutcomeAt(), date);
      expect((await other.getUser()).totalXp, 7);
      expect((await guestSource.getUser()).totalXp, 8);
      expect(other.getActivePlanId(), isNull);
      expect((await legacy.getUser()).totalXp, 999);
    },
  );

  test(
    'field clears affect only their profile, and reminders are device-local',
    () async {
      final prefs = await preferences();
      final legacy = LocalDataSource(prefs);
      final first = ProfileLocalDataSource(prefs, guest);
      final second = ProfileLocalDataSource(prefs, alice);
      final time = DateTime.utc(2026);
      for (final source in [legacy, first, second]) {
        await source.saveUser(UserModel(totalXp: 11));
        await source.saveActivePlanId('plan');
        await source.saveActivePlanStartedAt(time);
        await source.saveBookmarks([
          VerseBookmark(
            book: 'John',
            chapter: 1,
            verse: 1,
            translationId: 'web',
            createdAt: time,
          ),
        ]);
        await source.saveBookmarkTombstones({'key': time});
        await source.saveSyncLastOutcome('success');
        await source.saveSyncLastOutcomeAt(time);
      }
      await first.clearUser();
      await first.clearActivePlanId();
      await first.clearActivePlanStartedAt();
      await first.clearBookmarks();
      await first.clearBookmarkTombstones();
      await first.saveSyncLastOutcome('');
      await first.saveSyncLastOutcomeAt(null);
      expect((await first.getUser()).totalXp, 0);
      expect(first.getActivePlanId(), isNull);
      expect(first.getActivePlanStartedAt(), isNull);
      expect(first.getBookmarks(), isEmpty);
      expect(first.getBookmarkTombstones(), isEmpty);
      expect(first.getSyncLastOutcome(), isNull);
      expect(first.getSyncLastOutcomeAt(), isNull);
      await first.saveSyncLastOutcome('again');
      await first.saveSyncLastOutcome(null);
      expect(first.getSyncLastOutcome(), isNull);
      for (final source in [legacy, second]) {
        expect((await source.getUser()).totalXp, 11);
        expect(source.getActivePlanId(), 'plan');
        expect(source.getActivePlanStartedAt(), time);
        expect(source.getBookmarks(), hasLength(1));
        expect(source.getBookmarkTombstones(), {'key': time});
        expect(source.getSyncLastOutcome(), 'success');
        expect(source.getSyncLastOutcomeAt(), time);
      }
      expect(first.isDailyReminderEnabled(), false);
      expect(second.getDailyReminderTime(), '08:00');
      await first.saveDailyReminderEnabled(true);
      await second.saveDailyReminderTime('06:45');
      expect(legacy.isDailyReminderEnabled(), true);
      expect(first.getDailyReminderTime(), '06:45');
      expect(second.isDailyReminderEnabled(), true);
    },
  );

  test(
    'snapshots mutable inputs before queued writes and detaches reads',
    () async {
      final prefs = await preferences();
      final source = ProfileLocalDataSource(prefs, guest);
      final rewards = {'one'};
      final chapters = <int>{1};
      final user = UserModel(readingProgress: {'John': chapters});
      final tombstones = {'key': DateTime.utc(2026)};
      final writes = [
        source.saveCompletedPlanRewardIds(rewards),
        source.saveUser(user),
        source.saveBookmarkTombstones(tombstones),
      ];
      rewards.add('two');
      chapters.add(2);
      tombstones.clear();
      await Future.wait(writes);
      expect(source.getCompletedPlanRewardIds(), {'one'});
      expect((await source.getUser()).readingProgress['John'], {1});
      expect(source.getBookmarkTombstones(), {'key': DateTime.utc(2026)});
      source.getCompletedPlanRewardIds().add('changed');
      source.getBookmarkTombstones().clear();
      expect(source.getCompletedPlanRewardIds(), {'one'});
      expect(source.getBookmarkTombstones(), isNotEmpty);
    },
  );

  test(
    'explicit migration remains readable without altering legacy data',
    () async {
      final prefs = await preferences({
        'user_data': jsonEncode({'totalXp': 123}),
        'completed_plan_reward_ids': <String>['a', 'a', 'b'],
        'active_plan_id': 'legacy',
      });
      final storage = ProfileStorage(prefs);
      final source = ProfileLocalDataSource(prefs, guest);
      expect((await source.getUser()).totalXp, 0);
      expect(
        await storage.migrateLegacy(guest),
        LegacyMigrationResult.migrated,
      );
      expect((await source.getUser()).totalXp, 123);
      expect(source.getCompletedPlanRewardIds(), {'a', 'b'});
      await source.saveActivePlanId('changed');
      expect(prefs.getString('active_plan_id'), 'legacy');
      expect(ProfileLocalDataSource(prefs, alice).getActivePlanId(), isNull);
    },
  );

  test(
    'invalid stored data follows LocalDataSource parsing behavior',
    () async {
      final prefs = await preferences();
      final storage = ProfileStorage(prefs);
      final source = ProfileLocalDataSource(prefs, guest);
      await storage.set(guest, ProfileField.activePlanStartedAt, 'bad date');
      await storage.set(guest, ProfileField.cloudLastSyncedAt, '');
      await storage.set(guest, ProfileField.syncLastOutcomeAt, 'bad date');
      await storage.set(guest, ProfileField.bookmarks, '{}');
      await storage.set(
        guest,
        ProfileField.bookmarkTombstones,
        jsonEncode({'bad': 'invalid', 'ok': '2026-01-01'}),
      );
      expect(source.getActivePlanStartedAt(), isNull);
      expect(source.getCloudLastSyncedAt(), isNull);
      expect(source.getSyncLastOutcomeAt(), isNull);
      expect(source.getBookmarks(), isEmpty);
      expect(source.getBookmarkTombstones(), {'ok': DateTime(2026)});
      await storage.set(guest, ProfileField.bookmarkTombstones, '[]');
      expect(source.getBookmarkTombstones(), isEmpty);
      await storage.set(guest, ProfileField.bookmarks, '{broken');
      expect(source.getBookmarks, throwsFormatException);
      await storage.set(guest, ProfileField.userData, '{broken');
      await expectLater(source.getUser(), throwsFormatException);
    },
  );

  test('interrupted migration blocks writes without implicit retry', () async {
    final prefs = await preferences({
      'profile_storage_v1_legacy_migration': jsonEncode({
        'owner': 'guest',
        'complete': false,
        'data': {'active_plan_id': 'reserved'},
      }),
      'active_plan_id': 'legacy',
    });
    final source = ProfileLocalDataSource(prefs, guest);
    await expectLater(source.saveActivePlanId('new'), throwsStateError);
    await expectLater(source.clearUser(), throwsStateError);
    expect(source.getActivePlanId(), isNull);
    expect(prefs.getString('active_plan_id'), 'legacy');
    await ProfileStorage(prefs).migrateLegacy(guest);
    expect(source.getActivePlanId(), 'reserved');
  });
}
