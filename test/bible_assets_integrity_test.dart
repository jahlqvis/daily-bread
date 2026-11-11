import 'dart:convert';

import 'package:daily_bread/core/constants/app_constants.dart';
import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The bundled ASV intentionally contains empty placeholders for these
  // verse numbers, which are omitted from its main text.
  const asvOmissions = {
    'Matthew 17:21',
    'Matthew 18:11',
    'Matthew 23:14',
    'Mark 7:16',
    'Mark 9:44',
    'Mark 9:46',
    'Mark 11:26',
    'Mark 15:28',
    'Luke 17:36',
    'Luke 23:17',
    'John 5:4',
    'Acts 8:37',
    'Acts 15:34',
    'Acts 24:7',
    'Acts 28:29',
    'Romans 16:24',
  };

  for (final translation in BibleTranslation.values) {
    test('${translation.id} contains all books and chapters', () async {
      final blankReferences = <String>{};
      for (final book in AppConstants.booksOfTheBible) {
        final slug = BibleDataSource.assetSlugFor(book, translation);
        final path = '${translation.assetDirectory}/$slug.json';
        final data = jsonDecode(await rootBundle.loadString(path)) as Map;
        final chapters = data['chapters'] as List;
        final expectedCount = AppConstants.chaptersPerBook[book]!;
        expect(chapters.length, expectedCount, reason: path);
        final numbers = <int>{};
        for (final rawChapter in chapters) {
          final chapter = rawChapter as Map;
          final number = chapter['chapter'] as int;
          expect(numbers.add(number), isTrue, reason: path);
          expect(number, inInclusiveRange(1, expectedCount), reason: path);
          final verses = chapter['verses'] as List;
          expect(verses, isNotEmpty, reason: '$path chapter $number');
          final verseNumbers = <int>{};
          for (final rawVerse in verses) {
            final verse = rawVerse as Map;
            final verseNumber = verse['verse'] as int;
            expect(verseNumber, greaterThan(0), reason: path);
            expect(verseNumbers.add(verseNumber), isTrue, reason: path);
            final text = verse['text'] as String;
            if (text.trim().isEmpty) {
              blankReferences.add('$book $number:$verseNumber');
            }
          }
        }
      }
      expect(
        blankReferences,
        translation == BibleTranslation.asv ? asvOmissions : isEmpty,
      );
    });
  }
}
