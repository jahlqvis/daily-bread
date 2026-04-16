import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
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
      final chapter = dataSource.getChapter(
        '1 Samuel',
        1,
        BibleTranslation.kjv,
      );

      expect(chapter, isNotNull);
    });
  });

  group('BibleDataSource searchVerses', () {
    test('finds verses by phrase in selected translation', () async {
      final dataSource = BibleDataSource();

      final results = await dataSource.searchVerses(
        'in the beginning',
        BibleTranslation.web,
        books: const ['Genesis'],
      );

      expect(results, isNotEmpty);
      expect(results.first.book, 'Genesis');
      expect(results.first.chapter, 1);
      expect(results.first.verse, 1);
    });

    test('returns empty list when no verse matches query', () async {
      final dataSource = BibleDataSource();

      final results = await dataSource.searchVerses(
        'zzzzqwertynotaverse',
        BibleTranslation.kjv,
        books: const ['Genesis'],
      );

      expect(results, isEmpty);
    });
  });

  group('BibleDataSource search index behavior', () {
    setUp(() {
      BibleDataSource.clearCachesForTesting();
      BibleDataSource.setSearchIndexBooksForTesting(const ['Genesis', 'John']);
    });

    tearDown(() {
      BibleDataSource.clearCachesForTesting();
    });

    test(
      'builds index once and reuses it for repeated translation queries',
      () async {
        final dataSource = BibleDataSource();

        final first = await dataSource.searchVerses(
          'in the beginning',
          BibleTranslation.kjv,
        );
        final firstBuildCount = BibleDataSource.searchIndexBuildCountForTesting(
          BibleTranslation.kjv,
        );

        final second = await dataSource.searchVerses(
          'the word',
          BibleTranslation.kjv,
        );
        final secondBuildCount =
            BibleDataSource.searchIndexBuildCountForTesting(
              BibleTranslation.kjv,
            );

        expect(first, isNotEmpty);
        expect(second, isNotEmpty);
        expect(firstBuildCount, 1);
        expect(secondBuildCount, 1);
        expect(
          BibleDataSource.searchIndexSizeForTesting(BibleTranslation.kjv),
          greaterThan(0),
        );
      },
    );

    test('maintains separate search indexes per translation', () async {
      final dataSource = BibleDataSource();

      await dataSource.searchVerses('in the beginning', BibleTranslation.kjv);
      await dataSource.searchVerses('in the beginning', BibleTranslation.web);

      expect(
        BibleDataSource.searchIndexBuildCountForTesting(BibleTranslation.kjv),
        1,
      );
      expect(
        BibleDataSource.searchIndexBuildCountForTesting(BibleTranslation.web),
        1,
      );
      expect(
        BibleDataSource.searchIndexSizeForTesting(BibleTranslation.kjv),
        greaterThan(0),
      );
      expect(
        BibleDataSource.searchIndexSizeForTesting(BibleTranslation.web),
        greaterThan(0),
      );

      await dataSource.searchVerses('god', BibleTranslation.web);
      expect(
        BibleDataSource.searchIndexBuildCountForTesting(BibleTranslation.web),
        1,
      );
    });
  });
}
