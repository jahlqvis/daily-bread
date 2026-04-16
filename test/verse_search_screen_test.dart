import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/bible_passage_model.dart';
import 'package:daily_bread/data/repositories/user_repository.dart';
import 'package:daily_bread/presentation/providers/bible_provider.dart';
import 'package:daily_bread/presentation/providers/bookmarks_provider.dart';
import 'package:daily_bread/presentation/providers/user_provider.dart';
import 'package:daily_bread/presentation/screens/verse_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSearchDataSource extends BibleDataSource {
  int searchCallCount = 0;
  bool throwOnSearch = false;
  Duration searchDelay = Duration.zero;

  final Set<String> emptyQueries = {};

  final Map<String, Map<int, List<BiblePassage>>> _chapters = {
    'Genesis': {
      1: [
        BiblePassage(
          book: 'Genesis',
          chapter: 1,
          verse: 1,
          text: 'In the beginning God created the heaven and the earth.',
        ),
      ],
    },
    'John': {
      13: [
        BiblePassage(
          book: 'John',
          chapter: 13,
          verse: 34,
          text: 'A new commandment I give to you, that you love one another.',
        ),
      ],
    },
  };

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
    final verses = _chapters[book]?[chapter];
    if (verses == null) {
      return null;
    }
    return BibleChapter(book: book, chapter: chapter, verses: verses);
  }

  @override
  Future<List<BiblePassage>> searchVerses(
    String query,
    BibleTranslation translation, {
    int limit = 100,
    Iterable<String>? books,
  }) async {
    searchCallCount += 1;

    if (searchDelay > Duration.zero) {
      await Future<void>.delayed(searchDelay);
    }

    if (throwOnSearch) {
      throw Exception('search failed');
    }

    if (emptyQueries.contains(query)) {
      return [];
    }

    return [
      BiblePassage(
        book: 'John',
        chapter: 13,
        verse: 34,
        text: 'A new commandment I give to you, that you love one another.',
      ),
    ];
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

  Future<void> pumpSearchScreen(
    WidgetTester tester,
    _FakeSearchDataSource dataSource, {
    bool includeUserProvider = false,
    BibleProvider? bibleProvider,
    List<NavigatorObserver> navigatorObservers = const [],
  }) async {
    final provider = bibleProvider ?? BibleProvider(dataSource);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final localDataSource = LocalDataSource(prefs);

    final providers = <SingleChildWidget>[
      ChangeNotifierProvider<BibleProvider>.value(value: provider),
      ChangeNotifierProvider(
        create: (_) => BookmarksProvider(localDataSource)..loadBookmarks(),
      ),
    ];

    if (includeUserProvider) {
      final repository = UserRepository(localDataSource);
      providers.add(
        ChangeNotifierProvider(create: (_) => UserProvider(repository)),
      );
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          home: const VerseSearchScreen(),
          navigatorObservers: navigatorObservers,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('debounces search input before querying data source', (
    tester,
  ) async {
    final dataSource = _FakeSearchDataSource();
    await pumpSearchScreen(tester, dataSource);

    final finder = find.byType(TextField);

    await tester.enterText(finder, 'love');
    await tester.pump(const Duration(milliseconds: 200));
    expect(dataSource.searchCallCount, 0);

    await tester.pump(const Duration(milliseconds: 200));
    expect(dataSource.searchCallCount, 1);
    expect(find.text('John 13:34'), findsOneWidget);
  });

  testWidgets('requires at least two characters before searching', (
    tester,
  ) async {
    final dataSource = _FakeSearchDataSource();
    await pumpSearchScreen(tester, dataSource);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 400));

    expect(dataSource.searchCallCount, 0);
    expect(find.text('Type at least 2 characters to search.'), findsOneWidget);
  });

  testWidgets('shows loading indicator while search is running', (
    tester,
  ) async {
    final dataSource = _FakeSearchDataSource()
      ..searchDelay = const Duration(milliseconds: 500);
    await pumpSearchScreen(tester, dataSource);

    await tester.enterText(find.byType(TextField), 'love');
    await tester.pump(const Duration(milliseconds: 360));

    expect(find.text('Searching verses...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('John 13:34'), findsOneWidget);
  });

  testWidgets('shows error state and retry succeeds', (tester) async {
    final dataSource = _FakeSearchDataSource()..throwOnSearch = true;
    await pumpSearchScreen(tester, dataSource);

    await tester.enterText(find.byType(TextField), 'love');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump();

    expect(
      find.text('Could not search verses right now. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry Search'), findsOneWidget);

    dataSource.throwOnSearch = false;
    await tester.tap(find.text('Retry Search'));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('John 13:34'), findsOneWidget);
  });

  testWidgets('shows no results message for unmatched query', (tester) async {
    final dataSource = _FakeSearchDataSource()..emptyQueries.add('nomatch');
    await pumpSearchScreen(tester, dataSource);

    await tester.enterText(find.byType(TextField), 'nomatch');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump();

    expect(find.text('No verses found for "nomatch".'), findsOneWidget);
  });

  testWidgets('tapping result opens reading and sets jump context', (
    tester,
  ) async {
    final dataSource = _FakeSearchDataSource();
    final bibleProvider = BibleProvider(dataSource);
    final observer = _RecordingNavigatorObserver();
    await pumpSearchScreen(
      tester,
      dataSource,
      includeUserProvider: true,
      bibleProvider: bibleProvider,
      navigatorObservers: [observer],
    );

    await tester.enterText(find.byType(TextField), 'love');
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(ListTile).first);
    await tester.pump(const Duration(milliseconds: 250));

    expect(observer.pushCount, greaterThan(0));
    expect(bibleProvider.selectedBook, 'John');
    expect(bibleProvider.selectedChapter, 13);
    expect(bibleProvider.highlightedVerse, 34);
  });
}
