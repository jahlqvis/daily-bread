import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/app_constants.dart';
import '../../core/constants/bible_translation.dart';
import '../../core/utils/book_slug.dart';
import '../models/bible_passage_model.dart';

class BibleDataSource {
  static final Map<BibleTranslation, Map<String, Map<int, List<BiblePassage>>>>
  _bookCache = {};
  static final Map<String, Future<void>> _loadingBooks = {};
  static final Map<BibleTranslation, List<_SearchEntry>> _searchIndex = {};
  static final Map<BibleTranslation, Future<void>> _buildingSearchIndex = {};
  static final Map<BibleTranslation, int> _searchIndexBuildCounts = {};
  static List<String>? _searchIndexBooksOverride;

  Future<void> loadBibleData(BibleTranslation translation) async {
    await preloadBook(AppConstants.booksOfTheBible.first, translation);
  }

  Future<void> preloadBook(String book, BibleTranslation translation) async {
    final cache = _bookCache.putIfAbsent(translation, () => {});
    if (cache.containsKey(book)) return;
    final key = _loadingKey(book, translation);
    final existingLoader = _loadingBooks[key];
    if (existingLoader != null) {
      return existingLoader;
    }
    final loader = _loadBook(book, translation);
    _loadingBooks[key] = loader;
    try {
      await loader;
    } finally {
      _loadingBooks.remove(key);
    }
  }

  Future<void> _loadBook(String book, BibleTranslation translation) async {
    final slug = assetSlugFor(book, translation);
    final path = '${translation.assetDirectory}/$slug.json';
    final jsonString = await rootBundle.loadString(path);
    final Map<String, dynamic> jsonMap =
        jsonDecode(jsonString) as Map<String, dynamic>;
    final List<dynamic> chapters = jsonMap['chapters'] as List<dynamic>? ?? [];
    final chapterMap = <int, List<BiblePassage>>{};

    for (final dynamic chapterEntry in chapters) {
      if (chapterEntry is! Map<String, dynamic>) continue;
      final int? chapterNumber = chapterEntry['chapter'] as int?;
      final verses = chapterEntry['verses'] as List<dynamic>?;
      if (chapterNumber == null || verses == null) continue;

      final passages = verses
          .whereType<Map<String, dynamic>>()
          .map((verseEntry) {
            final int? verseNumber = verseEntry['verse'] as int?;
            final String? text = verseEntry['text'] as String?;
            if (verseNumber == null || text == null) {
              return null;
            }
            return BiblePassage(
              book: book,
              chapter: chapterNumber,
              verse: verseNumber,
              text: text.trim(),
            );
          })
          .whereType<BiblePassage>()
          .toList();

      if (passages.isNotEmpty) {
        chapterMap[chapterNumber] = passages;
      }
    }

    _bookCache[translation]![book] = chapterMap;
  }

  @visibleForTesting
  static String assetSlugFor(String book, BibleTranslation translation) {
    final baseSlug = bookSlug(book);
    if (translation == BibleTranslation.web) {
      return baseSlug;
    }

    final romanSlug = baseSlug.replaceFirstMapped(RegExp(r'^(1|2|3)_'), (
      match,
    ) {
      switch (match.group(1)) {
        case '1':
          return 'i_';
        case '2':
          return 'ii_';
        case '3':
          return 'iii_';
        default:
          return match.group(0) ?? '';
      }
    });

    if (romanSlug == 'revelation') {
      return 'revelation_of_john';
    }

    return romanSlug;
  }

  BibleChapter? getChapter(
    String book,
    int chapter,
    BibleTranslation translation,
  ) {
    final chapters = _bookCache[translation]?[book];
    if (chapters == null || !chapters.containsKey(chapter)) {
      return null;
    }
    return BibleChapter(
      book: book,
      chapter: chapter,
      verses: chapters[chapter]!,
    );
  }

  Future<List<BiblePassage>> searchVerses(
    String query,
    BibleTranslation translation, {
    int limit = 100,
    Iterable<String>? books,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return [];
    }

    final terms = normalized
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    final results = <BiblePassage>[];

    if (books != null) {
      return _searchInBooks(
        books: books,
        terms: terms,
        translation: translation,
        limit: limit,
      );
    }

    await _ensureSearchIndex(translation);
    final entries = _searchIndex[translation] ?? const [];

    for (final entry in entries) {
      final isMatch = terms.every(entry.normalizedText.contains);
      if (!isMatch) {
        continue;
      }

      results.add(entry.passage);
      if (results.length >= limit) {
        break;
      }
    }

    return results;
  }

  Future<List<BiblePassage>> _searchInBooks({
    required Iterable<String> books,
    required List<String> terms,
    required BibleTranslation translation,
    required int limit,
  }) async {
    final results = <BiblePassage>[];
    for (final book in books) {
      await preloadBook(book, translation);
      final chapters = _bookCache[translation]?[book];
      if (chapters == null || chapters.isEmpty) {
        continue;
      }

      final chapterNumbers = chapters.keys.toList()..sort();
      for (final chapter in chapterNumbers) {
        final verses = chapters[chapter] ?? const [];
        for (final verse in verses) {
          final text = verse.text.toLowerCase();
          final isMatch = terms.every(text.contains);
          if (!isMatch) {
            continue;
          }
          results.add(verse);
          if (results.length >= limit) {
            return results;
          }
        }
      }
    }
    return results;
  }

  Future<void> _ensureSearchIndex(BibleTranslation translation) async {
    if (_searchIndex.containsKey(translation)) {
      return;
    }

    final existingLoader = _buildingSearchIndex[translation];
    if (existingLoader != null) {
      return existingLoader;
    }

    final loader = _buildSearchIndex(translation);
    _buildingSearchIndex[translation] = loader;
    try {
      await loader;
    } finally {
      _buildingSearchIndex.remove(translation);
    }
  }

  Future<void> _buildSearchIndex(BibleTranslation translation) async {
    final entries = <_SearchEntry>[];
    final booksForIndex =
        _searchIndexBooksOverride ?? AppConstants.booksOfTheBible;
    for (final book in booksForIndex) {
      await preloadBook(book, translation);
      final chapters = _bookCache[translation]?[book];
      if (chapters == null || chapters.isEmpty) {
        continue;
      }

      final chapterNumbers = chapters.keys.toList()..sort();
      for (final chapter in chapterNumbers) {
        final verses = chapters[chapter] ?? const [];
        for (final verse in verses) {
          entries.add(
            _SearchEntry(
              passage: verse,
              normalizedText: verse.text.toLowerCase(),
            ),
          );
        }
      }
    }

    _searchIndex[translation] = entries;
    _searchIndexBuildCounts[translation] =
        (_searchIndexBuildCounts[translation] ?? 0) + 1;
  }

  @visibleForTesting
  static void clearCachesForTesting() {
    _bookCache.clear();
    _loadingBooks.clear();
    _searchIndex.clear();
    _buildingSearchIndex.clear();
    _searchIndexBuildCounts.clear();
    _searchIndexBooksOverride = null;
  }

  @visibleForTesting
  static void setSearchIndexBooksForTesting(Iterable<String>? books) {
    _searchIndexBooksOverride = books?.toList(growable: false);
  }

  @visibleForTesting
  static int searchIndexBuildCountForTesting(BibleTranslation translation) {
    return _searchIndexBuildCounts[translation] ?? 0;
  }

  @visibleForTesting
  static int searchIndexSizeForTesting(BibleTranslation translation) {
    return _searchIndex[translation]?.length ?? 0;
  }

  List<String> getBooks() {
    return AppConstants.booksOfTheBible;
  }

  int getChapterCount(String book) {
    return AppConstants.chaptersPerBook[book] ?? 0;
  }

  String _loadingKey(String book, BibleTranslation translation) {
    return '${translation.id}_$book';
  }
}

class _SearchEntry {
  final BiblePassage passage;
  final String normalizedText;

  const _SearchEntry({required this.passage, required this.normalizedText});
}
