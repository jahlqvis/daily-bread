import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:daily_bread/data/models/bible_passage_model.dart';
import 'package:daily_bread/presentation/providers/bible_provider.dart';
import 'package:daily_bread/presentation/screens/verse_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeSearchDataSource extends BibleDataSource {
  int searchCallCount = 0;

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
    return null;
  }

  @override
  Future<List<BiblePassage>> searchVerses(
    String query,
    BibleTranslation translation, {
    int limit = 100,
    Iterable<String>? books,
  }) async {
    searchCallCount += 1;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSearchScreen(
    WidgetTester tester,
    _FakeSearchDataSource dataSource,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BibleProvider(dataSource),
        child: const MaterialApp(home: VerseSearchScreen()),
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
}
