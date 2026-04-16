import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDataSource bookmarks persistence', () {
    test('returns empty list when no bookmarks are stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = LocalDataSource(prefs);

      expect(dataSource.getBookmarks(), isEmpty);
    });

    test('saves and restores bookmarks', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = LocalDataSource(prefs);

      final bookmarks = [
        VerseBookmark(
          book: 'John',
          chapter: 3,
          verse: 16,
          translationId: 'web',
          note: 'Core gospel verse',
          createdAt: DateTime(2026, 4, 16, 10, 15),
        ),
        VerseBookmark(
          book: 'Romans',
          chapter: 8,
          verse: 1,
          translationId: 'asv',
          createdAt: DateTime(2026, 4, 16, 11, 45),
        ),
      ];

      await dataSource.saveBookmarks(bookmarks);
      final restored = dataSource.getBookmarks();

      expect(restored.length, 2);
      expect(restored.first.reference, 'John 3:16');
      expect(restored.first.note, 'Core gospel verse');
      expect(restored.last.translationId, 'asv');
    });

    test('clears bookmarks', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = LocalDataSource(prefs);

      await dataSource.saveBookmarks([
        VerseBookmark(
          book: 'Genesis',
          chapter: 1,
          verse: 1,
          translationId: 'kjv',
          createdAt: DateTime(2026, 4, 16),
        ),
      ]);

      await dataSource.clearBookmarks();

      expect(dataSource.getBookmarks(), isEmpty);
    });
  });
}
