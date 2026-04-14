import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/user_model.dart';
import 'package:daily_bread/presentation/providers/reading_plan_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingPlanProvider', () {
    test('loads and persists active plan id', () async {
      SharedPreferences.setMockInitialValues({'active_plan_id': 'john_21'});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = LocalDataSource(prefs);
      final provider = ReadingPlanProvider(dataSource);

      await provider.loadPlanState();
      expect(provider.activePlanId, 'john_21');

      await provider.activatePlan('wisdom_14');
      expect(provider.activePlanId, 'wisdom_14');
      expect(dataSource.getActivePlanId(), 'wisdom_14');
    });

    test('returns next unread chapter and progress', () async {
      SharedPreferences.setMockInitialValues({'active_plan_id': 'john_21'});
      final prefs = await SharedPreferences.getInstance();
      final provider = ReadingPlanProvider(LocalDataSource(prefs));
      await provider.loadPlanState();

      final user = UserModel(
        readingProgress: {
          'John': {1, 2, 3},
        },
      );

      final next = provider.nextChapter(user);
      expect(next, isNotNull);
      expect(next!.book, 'John');
      expect(next.chapter, 4);
      expect(provider.completedCount(user), 3);
      expect(provider.progress(user), closeTo(3 / 21, 0.0001));
    });

    test('clears invalid persisted active plan id', () async {
      SharedPreferences.setMockInitialValues({
        'active_plan_id': 'missing_plan',
      });
      final prefs = await SharedPreferences.getInstance();
      final dataSource = LocalDataSource(prefs);
      final provider = ReadingPlanProvider(dataSource);

      await provider.loadPlanState();

      expect(provider.activePlanId, isNull);
      expect(dataSource.getActivePlanId(), isNull);
    });

    test(
      'returns null next chapter and completed progress when done',
      () async {
        SharedPreferences.setMockInitialValues({'active_plan_id': 'wisdom_14'});
        final prefs = await SharedPreferences.getInstance();
        final provider = ReadingPlanProvider(LocalDataSource(prefs));
        await provider.loadPlanState();

        final user = UserModel(
          readingProgress: {
            'Psalms': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
            'Proverbs': {1, 2, 3, 4},
          },
        );

        expect(provider.nextChapter(user), isNull);
        expect(provider.isCompleted(user), isTrue);
        expect(provider.progress(user), 1);
      },
    );

    test('throws when activating unknown plan id', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = ReadingPlanProvider(LocalDataSource(prefs));

      await expectLater(
        provider.activatePlan('does_not_exist'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
