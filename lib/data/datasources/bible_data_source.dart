import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/app_constants.dart';
import '../../core/utils/book_slug.dart';
import '../models/bible_passage_model.dart';

class BibleDataSource {
  static final Map<String, Map<int, List<BiblePassage>>> _bookCache = {};
  static final Map<String, Future<void>> _loadingBooks = {};
  static const String _booksBasePath = 'assets/bible/kjv_books';

  Future<void> loadBibleData() async {
    await preloadBook(AppConstants.booksOfTheBible.first);
  }

  Future<void> preloadBook(String book) async {
    if (_bookCache.containsKey(book)) return;
    final existingLoader = _loadingBooks[book];
    if (existingLoader != null) {
      return existingLoader;
    }
    final loader = _loadBook(book);
    _loadingBooks[book] = loader;
    try {
      await loader;
    } finally {
      _loadingBooks.remove(book);
    }
  }

  Future<void> _loadBook(String book) async {
    final slug = bookSlug(book);
    final path = '$_booksBasePath/$slug.json';
    final jsonString = await rootBundle.loadString(path);
    final Map<String, dynamic> jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
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
      }).whereType<BiblePassage>().toList();

      if (passages.isNotEmpty) {
        chapterMap[chapterNumber] = passages;
      }
    }

    _bookCache[book] = chapterMap;
  }

  BibleChapter? getChapter(String book, int chapter) {
    final chapters = _bookCache[book];
    if (chapters == null || !chapters.containsKey(chapter)) {
      return null;
    }
    return BibleChapter(
      book: book,
      chapter: chapter,
      verses: chapters[chapter]!,
    );
  }

  List<String> getBooks() {
    return AppConstants.booksOfTheBible;
  }

  int getChapterCount(String book) {
    return AppConstants.chaptersPerBook[book] ?? 0;
  }
}
