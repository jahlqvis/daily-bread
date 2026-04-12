import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/bible_passage_model.dart';
import '../../core/constants/app_constants.dart';

class BibleDataSource {
  static final Map<String, Map<int, List<BiblePassage>>> _kjvData = {};
  static const String _assetPath = 'assets/bible/kjv.json';

  Future<void> loadBibleData() async {
    if (_kjvData.isNotEmpty) return;
    final jsonString = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
    final List<dynamic> books = jsonMap['books'] as List<dynamic>? ?? [];

    for (final dynamic bookEntry in books) {
      if (bookEntry is! Map<String, dynamic>) continue;
      final String? bookName = bookEntry['name'] as String?;
      if (bookName == null) continue;

      final chapters = bookEntry['chapters'] as List<dynamic>?;
      if (chapters == null) continue;

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
            book: bookName,
            chapter: chapterNumber,
            verse: verseNumber,
            text: text.trim(),
          );
        }).whereType<BiblePassage>().toList();

        if (passages.isNotEmpty) {
          chapterMap[chapterNumber] = passages;
        }
      }

      if (chapterMap.isNotEmpty) {
        _kjvData[bookName] = chapterMap;
      }
    }
  }

  BibleChapter? getChapter(String book, int chapter) {
    final chapters = _kjvData[book];
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
