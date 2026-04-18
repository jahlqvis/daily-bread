import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/bible_passage_model.dart';
import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:daily_bread/data/repositories/user_repository.dart';
import 'package:daily_bread/presentation/providers/bible_provider.dart';
import 'package:daily_bread/presentation/providers/bookmarks_provider.dart';
import 'package:daily_bread/presentation/providers/reading_plan_provider.dart';
import 'package:daily_bread/presentation/providers/user_provider.dart';
import 'package:daily_bread/presentation/screens/reading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReadingDataSource extends BibleDataSource {
  @override
  Future<void> preloadBook(String book, BibleTranslation translation) async {}

  @override
  int getChapterCount(String book) => 50;

  @override
  BibleChapter? getChapter(
    String book,
    int chapter,
    BibleTranslation translation,
  ) {
    if (book != 'Genesis' || chapter != 1) {
      return null;
    }

    return BibleChapter(
      book: 'Genesis',
      chapter: 1,
      verses: List.generate(
        80,
        (index) => BiblePassage(
          book: 'Genesis',
          chapter: 1,
          verse: index + 1,
          text: index == 0
              ? 'In the beginning God created the heaven and the earth.'
              : 'Genesis 1:${index + 1} sample verse text.',
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<({BookmarksProvider bookmarksProvider})> pumpReadingScreen(
    WidgetTester tester, {
    List<VerseBookmark>? initialBookmarks,
    int? highlightedVerse,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final localDataSource = LocalDataSource(prefs);
    if (initialBookmarks != null) {
      await localDataSource.saveBookmarks(initialBookmarks);
    }

    final bibleProvider = BibleProvider(_FakeReadingDataSource());
    final userProvider = UserProvider(UserRepository(localDataSource));
    final bookmarksProvider = BookmarksProvider(localDataSource);
    final planProvider = ReadingPlanProvider(localDataSource);

    await Future.wait([
      bibleProvider.loadBible(),
      userProvider.loadUser(),
      bookmarksProvider.loadBookmarks(),
      planProvider.loadPlanState(),
    ]);

    if (highlightedVerse != null) {
      bibleProvider.setHighlightedVerse(highlightedVerse);
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BibleProvider>.value(value: bibleProvider),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<BookmarksProvider>.value(
            value: bookmarksProvider,
          ),
          ChangeNotifierProvider<ReadingPlanProvider>.value(
            value: planProvider,
          ),
        ],
        child: const MaterialApp(home: ReadingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    return (bookmarksProvider: bookmarksProvider);
  }

  testWidgets('long press bookmark opens note dialog and saves note', (
    tester,
  ) async {
    final result = await pumpReadingScreen(tester);

    await tester.longPress(find.byIcon(Icons.bookmark_border).first);
    await tester.pumpAndSettle();

    expect(find.text('Note for Genesis 1:1'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Creation starts here',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result.bookmarksProvider.bookmarks.length, 1);
    expect(
      result.bookmarksProvider.bookmarks.first.note,
      'Creation starts here',
    );
  });

  testWidgets('long press existing bookmark can clear note', (tester) async {
    final result = await pumpReadingScreen(
      tester,
      initialBookmarks: [
        VerseBookmark(
          book: 'Genesis',
          chapter: 1,
          verse: 1,
          translationId: 'kjv',
          note: 'Old note',
          createdAt: DateTime(2026, 4, 18),
        ),
      ],
    );

    await tester.longPress(find.byIcon(Icons.bookmark).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(result.bookmarksProvider.bookmarks.length, 1);
    expect(result.bookmarksProvider.bookmarks.first.note, isNull);
  });

  testWidgets('auto-scrolls to highlighted verse in long chapter', (tester) async {
    await pumpReadingScreen(tester, highlightedVerse: 70);

    expect(find.text('Jumped to verse 70'), findsOneWidget);
    expect(find.text('Genesis 1:70 sample verse text.'), findsOneWidget);
  });
}
