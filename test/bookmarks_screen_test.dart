import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/bible_passage_model.dart';
import 'package:daily_bread/data/models/verse_bookmark_model.dart';
import 'package:daily_bread/data/repositories/user_repository.dart';
import 'package:daily_bread/presentation/providers/bible_provider.dart';
import 'package:daily_bread/presentation/providers/bookmarks_provider.dart';
import 'package:daily_bread/presentation/providers/user_provider.dart';
import 'package:daily_bread/presentation/screens/bookmarks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBibleDataSource extends BibleDataSource {
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
    return BibleChapter(
      book: book,
      chapter: chapter,
      verses: [
        BiblePassage(
          book: book,
          chapter: chapter,
          verse: 1,
          text: 'Sample verse text for testing.',
        ),
      ],
    );
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({
      BibleProvider bibleProvider,
      BookmarksProvider bookmarksProvider,
      _RecordingNavigatorObserver observer,
    })
  >
  pumpBookmarksScreen(
    WidgetTester tester, {
    List<VerseBookmark>? bookmarks,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final localDataSource = LocalDataSource(prefs);
    if (bookmarks != null) {
      await localDataSource.saveBookmarks(bookmarks);
    }

    final bibleProvider = BibleProvider(_FakeBibleDataSource());
    final bookmarksProvider = BookmarksProvider(localDataSource);
    final userProvider = UserProvider(UserRepository(localDataSource));
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BibleProvider>.value(value: bibleProvider),
          ChangeNotifierProvider<BookmarksProvider>.value(
            value: bookmarksProvider,
          ),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ],
        child: MaterialApp(
          home: const BookmarksScreen(),
          navigatorObservers: [observer],
        ),
      ),
    );

    await bookmarksProvider.loadBookmarks();
    await tester.pumpAndSettle();

    return (
      bibleProvider: bibleProvider,
      bookmarksProvider: bookmarksProvider,
      observer: observer,
    );
  }

  testWidgets('shows empty state with start reading CTA', (tester) async {
    await pumpBookmarksScreen(tester, bookmarks: const []);

    expect(
      find.text('No bookmarks yet. Save your favorite verses while reading.'),
      findsOneWidget,
    );
    expect(find.text('Start Reading'), findsOneWidget);
  });

  testWidgets('renders bookmark metadata and note preview', (tester) async {
    await pumpBookmarksScreen(
      tester,
      bookmarks: [
        VerseBookmark(
          book: 'John',
          chapter: 3,
          verse: 16,
          translationId: 'web',
          note: 'Core gospel verse',
          createdAt: DateTime(2026, 4, 16),
        ),
      ],
    );

    expect(find.text('John 3:16'), findsOneWidget);
    expect(find.text('WEB'), findsOneWidget);
    expect(find.text('Core gospel verse'), findsOneWidget);
  });

  testWidgets('removes bookmark from overflow menu', (tester) async {
    final result = await pumpBookmarksScreen(
      tester,
      bookmarks: [
        VerseBookmark(
          book: 'Romans',
          chapter: 8,
          verse: 1,
          translationId: 'kjv',
          createdAt: DateTime(2026, 4, 16),
        ),
      ],
    );

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove bookmark'));
    await tester.pumpAndSettle();

    expect(result.bookmarksProvider.bookmarks, isEmpty);
    expect(find.text('Romans 8:1'), findsNothing);
  });

  testWidgets('edits bookmark note from overflow menu', (tester) async {
    final result = await pumpBookmarksScreen(
      tester,
      bookmarks: [
        VerseBookmark(
          book: 'Psalms',
          chapter: 23,
          verse: 1,
          translationId: 'asv',
          note: 'Old note',
          createdAt: DateTime(2026, 4, 16),
        ),
      ],
    );

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Updated note');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result.bookmarksProvider.bookmarks.first.note, 'Updated note');
    expect(find.text('Updated note'), findsOneWidget);
  });

  testWidgets('tapping bookmark sets reading jump context and navigates', (
    tester,
  ) async {
    final result = await pumpBookmarksScreen(
      tester,
      bookmarks: [
        VerseBookmark(
          book: 'Genesis',
          chapter: 1,
          verse: 1,
          translationId: 'web',
          createdAt: DateTime(2026, 4, 16),
        ),
      ],
    );

    await tester.tap(find.text('Genesis 1:1'));
    await tester.pumpAndSettle();

    expect(result.bibleProvider.selectedTranslation, BibleTranslation.web);
    expect(result.bibleProvider.selectedBook, 'Genesis');
    expect(result.bibleProvider.selectedChapter, 1);
    expect(result.bibleProvider.highlightedVerse, 1);
    expect(result.observer.pushCount, greaterThan(0));
  });
}
