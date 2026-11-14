import 'package:daily_bread/core/constants/bible_translation.dart';
import 'package:daily_bread/data/datasources/bible_data_source.dart';
import 'package:daily_bread/data/datasources/translation_preferences.dart';
import 'package:daily_bread/presentation/providers/bible_provider.dart';
import 'package:daily_bread/presentation/screens/translation_choice_screen.dart';
import 'package:daily_bread/presentation/widgets/translation_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingTranslationPreferences extends TranslationPreferences {
  _FailingTranslationPreferences(super.prefs);

  @override
  Future<void> saveTranslation(BibleTranslation translation) async {
    throw StateError('storage unavailable');
  }
}

BibleDataSource _sampleBibleDataSource() => BibleDataSource(
  assetStringLoader: (_) async =>
      '{"chapters":[{"chapter":1,"verses":[{"verse":1,"text":"Sample verse"}]}]}',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BibleDataSource.clearCachesForTesting();
  });
  tearDown(BibleDataSource.clearCachesForTesting);

  for (final translation in BibleTranslation.values) {
    test(
      'choosing ${translation.id} persists and loads verses',
      () async {
        final local = TranslationPreferences(
          await SharedPreferences.getInstance(),
        );
        final provider = BibleProvider(
          _sampleBibleDataSource(),
          translationPreferences: local,
        );
        expect(provider.hasChosenTranslation, isFalse);

        await provider.selectTranslation(translation);
        expect(provider.hasChosenTranslation, isTrue);
        expect(provider.selectedTranslation, translation);
        expect(provider.getCurrentChapter()?.verses, isNotEmpty);

        final restored = BibleProvider(
          _sampleBibleDataSource(),
          translationPreferences: local,
        );
        expect(restored.hasChosenTranslation, isTrue);
        expect(restored.selectedTranslation, translation);
        await restored.loadBible();
        expect(restored.getCurrentChapter()?.verses, isNotEmpty);
      },
    );
  }

  test('later translation changes are persisted', () async {
    final local = TranslationPreferences(await SharedPreferences.getInstance());
    final provider = BibleProvider(
      _sampleBibleDataSource(),
      translationPreferences: local,
    );
    await provider.selectTranslation(BibleTranslation.kjv);
    await provider.selectTranslation(BibleTranslation.web);

    final restored = BibleProvider(
      _sampleBibleDataSource(),
      translationPreferences: local,
    );
    expect(restored.selectedTranslation, BibleTranslation.web);
  });

  test('unrecognized stored value requires a new choice', () async {
    SharedPreferences.setMockInitialValues({'bible_translation': 'unknown'});
    final local = TranslationPreferences(await SharedPreferences.getInstance());
    expect(
      BibleProvider(
        _sampleBibleDataSource(),
        translationPreferences: local,
      ).hasChosenTranslation,
      isFalse,
    );
  });

  testWidgets(
    'first launch asks for a choice and returns to app on selection',
    (tester) async {
      final local = TranslationPreferences(
        await SharedPreferences.getInstance(),
      );
      final provider = BibleProvider(
        _sampleBibleDataSource(),
        translationPreferences: local,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: TranslationChoiceGate(child: Scaffold(body: Text('Home'))),
          ),
        ),
      );

      expect(find.text('Choose your Bible translation'), findsOneWidget);
      expect(find.textContaining('offline without an account'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('American Standard Version (ASV)'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(provider.selectedTranslation, BibleTranslation.asv);

      final restored = BibleProvider(
        _sampleBibleDataSource(),
        translationPreferences: local,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: restored,
          child: const MaterialApp(
            home: TranslationChoiceGate(child: Scaffold(body: Text('Home'))),
          ),
        ),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Choose your Bible translation'), findsNothing);
    },
  );

  testWidgets('storage failure keeps the choice screen and allows retry', (
    tester,
  ) async {
    final local = _FailingTranslationPreferences(
      await SharedPreferences.getInstance(),
    );
    final provider = BibleProvider(
      _sampleBibleDataSource(),
      translationPreferences: local,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: TranslationChoiceGate(child: Scaffold(body: Text('Home'))),
        ),
      ),
    );
    await tester.tap(find.text('King James Version (KJV)'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save your choice. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Home'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('later storage failure is visible and retains the choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'bible_translation': 'kjv'});
    final local = _FailingTranslationPreferences(
      await SharedPreferences.getInstance(),
    );
    final provider = BibleProvider(
      _sampleBibleDataSource(),
      translationPreferences: local,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: TranslationSelector(),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Select translation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('World English Bible (WEB)'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save your choice. Please try again.'),
      findsOneWidget,
    );
    expect(provider.selectedTranslation, BibleTranslation.kjv);
    expect(local.getTranslation(), BibleTranslation.kjv);
  });
}
