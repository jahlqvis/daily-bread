import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BibleDataSource.assetSlugFor', () {
    test('uses roman numerals for KJV/ASV assets', () {
      expect(
        BibleDataSource.assetSlugFor('1 Samuel', BibleTranslation.kjv),
        'i_samuel',
      );
      expect(
        BibleDataSource.assetSlugFor('2 Corinthians', BibleTranslation.asv),
        'ii_corinthians',
      );
      expect(
        BibleDataSource.assetSlugFor('3 John', BibleTranslation.kjv),
        'iii_john',
      );
    });

    test('keeps numeric slugs for WEB assets', () {
      expect(
        BibleDataSource.assetSlugFor('1 Samuel', BibleTranslation.web),
        '1_samuel',
      );
      expect(
        BibleDataSource.assetSlugFor('2 Corinthians', BibleTranslation.web),
        '2_corinthians',
      );
    });

    test('maps Revelation filename per translation', () {
      expect(
        BibleDataSource.assetSlugFor('Revelation', BibleTranslation.kjv),
        'revelation_of_john',
      );
      expect(
        BibleDataSource.assetSlugFor('Revelation', BibleTranslation.asv),
        'revelation_of_john',
      );
      expect(
        BibleDataSource.assetSlugFor('Revelation', BibleTranslation.web),
        'revelation',
      );
    });
  });

  group('BibleDataSource preloadBook', () {
    test('loads Genesis for WEB translation', () async {
      final dataSource = BibleDataSource();

      await dataSource.preloadBook('Genesis', BibleTranslation.web);
      final chapter = dataSource.getChapter('Genesis', 1, BibleTranslation.web);

      expect(chapter, isNotNull);
      expect(chapter!.verses, isNotEmpty);
    });

    test('loads 1 Samuel for KJV translation', () async {
      final dataSource = BibleDataSource();

      await dataSource.preloadBook('1 Samuel', BibleTranslation.kjv);
      final chapter = dataSource.getChapter('1 Samuel', 1, BibleTranslation.kjv);

      expect(chapter, isNotNull);
    });
  });
}
