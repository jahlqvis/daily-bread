import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:daily_bread/presentation/providers/bookmarks_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookmarksProvider', () {
    test('loads bookmarks sorted by newest first', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = LocalDataSource(prefs);

      await dataSource.saveBookmarks([
        VerseBookmark(
          book: 'John',
          chapter: 3,
          verse: 16,
          translationId: 'web',
          createdAt: DateTime(2026, 4, 10),
        ),
        VerseBookmark(
          book: 'Romans',
          chapter: 8,
          verse: 1,
          translationId: 'kjv',
          createdAt: DateTime(2026, 4, 12),
        ),
      ]);

      final provider = BookmarksProvider(dataSource);
      await provider.loadBookmarks();

      expect(provider.bookmarks.first.reference, 'Romans 8:1');
      expect(provider.bookmarks.last.reference, 'John 3:16');
    });

    test('addBookmark prevents duplicates and persists bookmarks', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = LocalDataSource(prefs);
      final provider = BookmarksProvider(dataSource);
      await provider.loadBookmarks();

      final bookmark = VerseBookmark(
        book: 'Genesis',
        chapter: 1,
        verse: 1,
        translationId: 'asv',
        createdAt: DateTime(2026, 4, 16, 12),
      );

      await provider.addBookmark(bookmark);
      await provider.addBookmark(bookmark);

      expect(provider.bookmarks.length, 1);
      expect(provider.isBookmarked('Genesis', 1, 1, 'asv'), isTrue);

      final persisted = dataSource.getBookmarks();
      expect(persisted.length, 1);
      expect(persisted.first.id, bookmark.id);
    });

    test('toggleBookmark adds and removes bookmark', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = BookmarksProvider(LocalDataSource(prefs));
      await provider.loadBookmarks();

      await provider.toggleBookmark(
        book: 'Psalms',
        chapter: 23,
        verse: 1,
        translationId: 'kjv',
        createdAt: DateTime(2026, 4, 16, 13),
      );
      expect(provider.bookmarks.length, 1);

      await provider.toggleBookmark(
        book: 'Psalms',
        chapter: 23,
        verse: 1,
        translationId: 'kjv',
      );
      expect(provider.bookmarks, isEmpty);
      expect(provider.tombstones['kjv|Psalms|23|1'], isNotNull);
    });

    test('re-adding removed bookmark clears tombstone', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = BookmarksProvider(LocalDataSource(prefs));
      await provider.loadBookmarks();

      await provider.toggleBookmark(
        book: 'Psalms',
        chapter: 23,
        verse: 1,
        translationId: 'kjv',
        createdAt: DateTime(2026, 4, 16, 13),
      );
      await provider.toggleBookmark(
        book: 'Psalms',
        chapter: 23,
        verse: 1,
        translationId: 'kjv',
      );

      expect(provider.tombstones['kjv|Psalms|23|1'], isNotNull);

      await provider.toggleBookmark(
        book: 'Psalms',
        chapter: 23,
        verse: 1,
        translationId: 'kjv',
      );

      expect(provider.bookmarks.length, 1);
      expect(provider.tombstones.containsKey('kjv|Psalms|23|1'), isFalse);
    });

    test('updateNote updates and clears note for existing bookmark', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = BookmarksProvider(LocalDataSource(prefs));
      await provider.loadBookmarks();

      await provider.toggleBookmark(
        book: 'John',
        chapter: 15,
        verse: 5,
        translationId: 'web',
        createdAt: DateTime(2026, 4, 16, 9),
      );

      await provider.updateNote('John', 15, 5, 'web', 'Abide in me');
      expect(provider.bookmarks.first.note, 'Abide in me');

      await provider.updateNote('John', 15, 5, 'web', '   ');
      expect(provider.bookmarks.first.note, isNull);
    });
  });
}
