import 'package:daily_bread/data/models/user_model.dart';
import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:daily_bread/services/cloud/cloud_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudSyncMerger', () {
    test('snapshot json roundtrip preserves tombstones and updatedAt', () {
      final snapshot = CloudSyncSnapshot(
        syncedAt: DateTime(2026, 4, 21, 8),
        user: UserModel(currentStreak: 2),
        bookmarks: [
          VerseBookmark(
            book: 'John',
            chapter: 3,
            verse: 16,
            translationId: 'web',
            createdAt: DateTime(2026, 4, 21, 7),
            updatedAt: DateTime(2026, 4, 21, 7, 30),
          ),
        ],
        tombstones: {'web|Romans|8|1': DateTime(2026, 4, 20, 6)},
      );

      final decoded = CloudSyncSnapshot.fromJson(snapshot.toJson());
      expect(decoded.bookmarks.single.updatedAt, DateTime(2026, 4, 21, 7, 30));
      expect(decoded.tombstones['web|Romans|8|1'], DateTime(2026, 4, 20, 6));
    });

    test('merges user progress, badges, and newest streak fields', () {
      final local = CloudSyncSnapshot(
        syncedAt: DateTime(2026, 4, 19, 10),
        user: UserModel(
          currentStreak: 3,
          longestStreak: 8,
          totalXp: 500,
          level: 3,
          badges: const ['first_read'],
          lastReadDate: DateTime(2026, 4, 19),
          readingProgress: {
            'Genesis': {1, 2},
          },
          streakFreezes: 1,
        ),
        bookmarks: const [],
      );

      final remote = CloudSyncSnapshot(
        syncedAt: DateTime(2026, 4, 19, 9),
        user: UserModel(
          currentStreak: 2,
          longestStreak: 9,
          totalXp: 450,
          level: 2,
          badges: const ['streak_7'],
          lastReadDate: DateTime(2026, 4, 18),
          readingProgress: {
            'Genesis': {2, 3},
            'John': {1},
          },
          streakFreezes: 0,
        ),
        bookmarks: const [],
      );

      final merged = CloudSyncMerger.merge(local: local, remote: remote);
      expect(merged.user.currentStreak, 3);
      expect(merged.user.longestStreak, 9);
      expect(merged.user.totalXp, 500);
      expect(merged.user.level, 3);
      expect(merged.user.badges, containsAll(['first_read', 'streak_7']));
      expect(merged.user.readingProgress['Genesis'], {1, 2, 3});
      expect(merged.user.readingProgress['John'], {1});
    });

    test('merges bookmarks by id and keeps latest updatedAt', () {
      final localBookmark = VerseBookmark(
        book: 'John',
        chapter: 3,
        verse: 16,
        translationId: 'web',
        note: 'Local',
        createdAt: DateTime(2026, 4, 19, 8),
        updatedAt: DateTime(2026, 4, 19, 8, 30),
      );
      final remoteBookmark = VerseBookmark(
        book: 'John',
        chapter: 3,
        verse: 16,
        translationId: 'web',
        note: 'Remote newer',
        createdAt: DateTime(2026, 4, 19, 9),
        updatedAt: DateTime(2026, 4, 19, 9, 30),
      );

      final merged = CloudSyncMerger.merge(
        local: CloudSyncSnapshot(
          syncedAt: DateTime(2026, 4, 19, 10),
          user: UserModel(),
          bookmarks: [
            localBookmark,
            VerseBookmark(
              book: 'Genesis',
              chapter: 1,
              verse: 1,
              translationId: 'web',
              createdAt: DateTime(2026, 4, 18),
            ),
          ],
        ),
        remote: CloudSyncSnapshot(
          syncedAt: DateTime(2026, 4, 19, 11),
          user: UserModel(),
          bookmarks: [remoteBookmark],
        ),
      );

      expect(merged.bookmarks.length, 2);
      final mergedJohn = merged.bookmarks.firstWhere(
        (bookmark) => bookmark.reference == 'John 3:16',
      );
      expect(mergedJohn.note, 'Remote newer');
    });

    test('keeps deletion when tombstone is newer than bookmark update', () {
      final bookmarkId = 'web|John|3|16';
      final merged = CloudSyncMerger.merge(
        local: CloudSyncSnapshot(
          syncedAt: DateTime(2026, 4, 19, 10),
          user: UserModel(),
          bookmarks: [
            VerseBookmark(
              book: 'John',
              chapter: 3,
              verse: 16,
              translationId: 'web',
              createdAt: DateTime(2026, 4, 19, 8),
              updatedAt: DateTime(2026, 4, 19, 8, 20),
            ),
          ],
        ),
        remote: CloudSyncSnapshot(
          syncedAt: DateTime(2026, 4, 19, 11),
          user: UserModel(),
          bookmarks: const [],
          tombstones: {bookmarkId: DateTime(2026, 4, 19, 9)},
        ),
      );

      expect(merged.bookmarks, isEmpty);
      expect(merged.tombstones[bookmarkId], DateTime(2026, 4, 19, 9));
    });

    test('keeps bookmark when update is newer than tombstone', () {
      final bookmarkId = 'web|John|3|16';
      final merged = CloudSyncMerger.merge(
        local: CloudSyncSnapshot(
          syncedAt: DateTime(2026, 4, 19, 10),
          user: UserModel(),
          bookmarks: [
            VerseBookmark(
              book: 'John',
              chapter: 3,
              verse: 16,
              translationId: 'web',
              note: 'Restored locally',
              createdAt: DateTime(2026, 4, 19, 8),
              updatedAt: DateTime(2026, 4, 19, 10, 10),
            ),
          ],
          tombstones: {bookmarkId: DateTime(2026, 4, 19, 9, 30)},
        ),
        remote: CloudSyncSnapshot(
          syncedAt: DateTime(2026, 4, 19, 11),
          user: UserModel(),
          bookmarks: const [],
          tombstones: {bookmarkId: DateTime(2026, 4, 19, 9)},
        ),
      );

      expect(merged.bookmarks.length, 1);
      expect(merged.bookmarks.single.note, 'Restored locally');
      expect(merged.tombstones.containsKey(bookmarkId), isFalse);
    });

    test('out-of-order device sync converges on newest delete', () {
      final bookmarkId = 'web|John|3|16';
      final deviceADelete = CloudSyncSnapshot(
        syncedAt: DateTime(2026, 4, 19, 11),
        user: UserModel(),
        bookmarks: const [],
        tombstones: {bookmarkId: DateTime(2026, 4, 19, 11)},
      );

      final staleDeviceBEdit = CloudSyncSnapshot(
        syncedAt: DateTime(2026, 4, 19, 11, 5),
        user: UserModel(),
        bookmarks: [
          VerseBookmark(
            book: 'John',
            chapter: 3,
            verse: 16,
            translationId: 'web',
            note: 'B stale edit',
            createdAt: DateTime(2026, 4, 19, 9),
            updatedAt: DateTime(2026, 4, 19, 10, 30),
          ),
        ],
      );

      final merged = CloudSyncMerger.merge(
        local: staleDeviceBEdit,
        remote: deviceADelete,
      );

      expect(merged.bookmarks, isEmpty);
      expect(merged.tombstones[bookmarkId], DateTime(2026, 4, 19, 11));
    });

    test('stale local reupload cannot resurrect remote tombstone', () {
      final bookmarkId = 'web|Romans|8|1';
      final staleLocal = CloudSyncSnapshot(
        syncedAt: DateTime(2026, 4, 20, 8),
        user: UserModel(),
        bookmarks: [
          VerseBookmark(
            book: 'Romans',
            chapter: 8,
            verse: 1,
            translationId: 'web',
            note: 'Old local copy',
            createdAt: DateTime(2026, 4, 18, 8),
            updatedAt: DateTime(2026, 4, 18, 8, 30),
          ),
        ],
      );

      final remoteDeleted = CloudSyncSnapshot(
        syncedAt: DateTime(2026, 4, 20, 8, 5),
        user: UserModel(),
        bookmarks: const [],
        tombstones: {bookmarkId: DateTime(2026, 4, 19, 12)},
      );

      final merged = CloudSyncMerger.merge(
        local: staleLocal,
        remote: remoteDeleted,
      );

      expect(merged.bookmarks, isEmpty);
      expect(merged.tombstones[bookmarkId], DateTime(2026, 4, 19, 12));
    });
  });
}
