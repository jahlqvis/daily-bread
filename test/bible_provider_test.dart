import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:daily_bread/data/models/bible_passage_model.dart';
import 'package:daily_bread/presentation/providers/bible_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBibleDataSource extends BibleDataSource {
  final List<String> preloadCalls = [];
  final List<String> searchCalls = [];

  bool throwOnSearch = false;
  bool throwOnPreload = false;

  final Map<BibleTranslation, List<BiblePassage>> _searchResponses = {
    BibleTranslation.kjv: [
      BiblePassage(
        book: 'Genesis',
        chapter: 1,
        verse: 1,
        text: 'In the beginning God created the heaven and the earth.',
      ),
    ],
    BibleTranslation.asv: [
      BiblePassage(
        book: 'John',
        chapter: 3,
        verse: 16,
        text: 'For God so loved the world, that he gave his only begotten Son.',
      ),
    ],
    BibleTranslation.web: [
      BiblePassage(
        book: 'Romans',
        chapter: 8,
        verse: 1,
        text:
            'There is therefore now no condemnation for those who are in Christ Jesus.',
      ),
    ],
  };

  final Map<BibleTranslation, Map<String, Map<int, List<BiblePassage>>>>
  _chapters = {
    BibleTranslation.kjv: {
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
        1: [
          BiblePassage(
            book: 'John',
            chapter: 1,
            verse: 1,
            text: 'In the beginning was the Word.',
          ),
        ],
      },
    },
    BibleTranslation.asv: {
      'Genesis': {
        1: [
          BiblePassage(
            book: 'Genesis',
            chapter: 1,
            verse: 1,
            text: 'In the beginning God created the heavens and the earth.',
          ),
        ],
      },
      'John': {
        1: [
          BiblePassage(
            book: 'John',
            chapter: 1,
            verse: 1,
            text: 'In the beginning was the Word.',
          ),
        ],
      },
    },
    BibleTranslation.web: {
      'Genesis': {
        1: [
          BiblePassage(
            book: 'Genesis',
            chapter: 1,
            verse: 1,
            text: 'In the beginning, God created the heavens and the earth.',
          ),
        ],
      },
      'John': {
        1: [
          BiblePassage(
            book: 'John',
            chapter: 1,
            verse: 1,
            text: 'In the beginning was the Word.',
          ),
        ],
      },
    },
  };

  @override
  Future<void> preloadBook(String book, BibleTranslation translation) async {
    if (throwOnPreload) {
      throw Exception('preload failure');
    }
    preloadCalls.add('${translation.id}:$book');
  }

  @override
  BibleChapter? getChapter(
    String book,
    int chapter,
    BibleTranslation translation,
  ) {
    final verses = _chapters[translation]?[book]?[chapter];
    if (verses == null) {
      return null;
    }
    return BibleChapter(book: book, chapter: chapter, verses: verses);
  }

  @override
  int getChapterCount(String book) {
    return 1;
  }

  @override
  Future<List<BiblePassage>> searchVerses(
    String query,
    BibleTranslation translation, {
    int limit = 100,
    Iterable<String>? books,
  }) async {
    searchCalls.add('${translation.id}:$query');
    if (throwOnSearch) {
      throw Exception('search failure');
    }
    return _searchResponses[translation] ?? const [];
  }
}

void main() {
  group('BibleProvider search and selection', () {
    test('empty query clears previous search results', () async {
      final dataSource = _FakeBibleDataSource();
      final provider = BibleProvider(dataSource);

      await provider.searchVerses('beginning');
      expect(provider.searchResults, isNotEmpty);
      expect(provider.lastSearchQuery, 'beginning');

      await provider.searchVerses('   ');
      expect(provider.searchResults, isEmpty);
      expect(provider.lastSearchQuery, isEmpty);
      expect(provider.searchError, isNull);
      expect(provider.isSearching, isFalse);
    });

    test('translation change re-runs latest search query', () async {
      final dataSource = _FakeBibleDataSource();
      final provider = BibleProvider(dataSource);

      await provider.searchVerses('grace');
      expect(provider.searchResults.first.book, 'Genesis');
      expect(dataSource.searchCalls, contains('kjv:grace'));

      await provider.selectTranslation(BibleTranslation.web);

      expect(provider.selectedTranslation, BibleTranslation.web);
      expect(dataSource.searchCalls, contains('web:grace'));
      expect(provider.searchResults.first.book, 'Romans');
    });

    test('translation change does not search when query is empty', () async {
      final dataSource = _FakeBibleDataSource();
      final provider = BibleProvider(dataSource);

      await provider.selectTranslation(BibleTranslation.asv);

      expect(provider.selectedTranslation, BibleTranslation.asv);
      expect(dataSource.searchCalls, isEmpty);
      expect(dataSource.preloadCalls, contains('asv:Genesis'));
    });

    test('search errors surface user-facing error state', () async {
      final dataSource = _FakeBibleDataSource()..throwOnSearch = true;
      final provider = BibleProvider(dataSource);

      await provider.searchVerses('hope');

      expect(provider.searchResults, isEmpty);
      expect(provider.searchError, isNotNull);
      expect(provider.isSearching, isFalse);
    });

    test('clearSearchResults resets existing search state', () async {
      final dataSource = _FakeBibleDataSource();
      final provider = BibleProvider(dataSource);

      await provider.searchVerses('grace');

      expect(provider.lastSearchQuery, 'grace');
      expect(provider.searchResults, isNotEmpty);

      provider.clearSearchResults();

      expect(provider.lastSearchQuery, isEmpty);
      expect(provider.searchResults, isEmpty);
      expect(provider.searchError, isNull);
      expect(provider.isSearching, isFalse);
    });

    test('load and retry update loadError state correctly', () async {
      final dataSource = _FakeBibleDataSource()..throwOnPreload = true;
      final provider = BibleProvider(dataSource);

      await provider.loadBible();

      expect(provider.loadError, isNotNull);
      expect(provider.isLoading, isFalse);

      dataSource.throwOnPreload = false;
      await provider.retryCurrentSelection();

      expect(provider.loadError, isNull);
      expect(provider.isLoading, isFalse);
      expect(dataSource.preloadCalls.length, 1);
      expect(dataSource.preloadCalls.first, 'kjv:Genesis');
    });

    test(
      'highlighted verse resets when chapter, book, or translation changes',
      () async {
        final dataSource = _FakeBibleDataSource();
        final provider = BibleProvider(dataSource);

        provider.setHighlightedVerse(7);
        expect(provider.highlightedVerse, 7);

        provider.selectChapter(2);
        expect(provider.highlightedVerse, isNull);

        provider.setHighlightedVerse(3);
        await provider.selectBook('John');
        expect(provider.highlightedVerse, isNull);

        provider.setHighlightedVerse(1);
        await provider.selectTranslation(BibleTranslation.asv);
        expect(provider.highlightedVerse, isNull);
      },
    );
  });
}
