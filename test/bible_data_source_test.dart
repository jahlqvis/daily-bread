import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

const _genesisWeb =
    '{"chapters":[{"chapter":1,"verses":[{"verse":1,"text":"In the beginning God created the heavens and the earth."},{"verse":2,"text":"The earth was formless and empty."}]}]}';
const _genesisKjv =
    '{"chapters":[{"chapter":1,"verses":[{"verse":1,"text":"In the beginning God created the heaven and the earth."},{"verse":2,"text":"And the earth was without form, and void."}]}]}';
const _johnWeb =
    '{"chapters":[{"chapter":1,"verses":[{"verse":1,"text":"In the beginning was the Word, and the Word was with God, and the Word was God."}]}]}';
const _johnKjv =
    '{"chapters":[{"chapter":1,"verses":[{"verse":1,"text":"In the beginning was the Word, and the Word was with God, and the Word was God."}]}]}';
const _samuelKjv =
    '{"chapters":[{"chapter":1,"verses":[{"verse":1,"text":"Now there was a certain man."}]}]}';

Map<String, String> _fixtureAssets() {
  return {
    'assets/bible/web_books/genesis.json': _genesisWeb,
    'assets/bible/kjv_books/genesis.json': _genesisKjv,
    'assets/bible/web_books/john.json': _johnWeb,
    'assets/bible/kjv_books/john.json': _johnKjv,
    'assets/bible/kjv_books/i_samuel.json': _samuelKjv,
  };
}

BibleDataSource _fixtureDataSource({
  Map<String, String>? overrides,
  Iterable<String> removePaths = const [],
}) {
  final fixtures = _fixtureAssets()..addAll(overrides ?? const {});
  for (final path in removePaths) {
    fixtures.remove(path);
  }
  return BibleDataSource(
    assetStringLoader: (path) async {
      final value = fixtures[path];
      if (value == null) {
        throw StateError('Missing fixture for $path');
      }
      return value;
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(BibleDataSource.clearCachesForTesting);
  tearDown(BibleDataSource.clearCachesForTesting);

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
      final dataSource = _fixtureDataSource();

      await dataSource.preloadBook('Genesis', BibleTranslation.web);
      final chapter = dataSource.getChapter('Genesis', 1, BibleTranslation.web);

      expect(chapter, isNotNull);
      expect(chapter!.verses, isNotEmpty);
    });

    test('loads 1 Samuel for KJV translation', () async {
      final dataSource = _fixtureDataSource();

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
      final dataSource = _fixtureDataSource();

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
      final dataSource = _fixtureDataSource();

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
      BibleDataSource.setSearchIndexBooksForTesting(const ['Genesis', 'John']);
    });

    tearDown(() {
      BibleDataSource.setSearchIndexBooksForTesting(null);
    });

    test(
      'builds index once and reuses it for repeated translation queries',
      () async {
        final dataSource = _fixtureDataSource();

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
      final dataSource = _fixtureDataSource();

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

    test('throws deterministic error when fixture asset is missing', () async {
      final dataSource = _fixtureDataSource(
        removePaths: const ['assets/bible/kjv_books/genesis.json'],
      );

      await expectLater(
        () => dataSource.searchVerses(
          'beginning',
          BibleTranslation.kjv,
          books: const ['Genesis'],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
