import 'package:daily_bread/core/constants/app_constants.dart';
import 'package:daily_bread/data/datasources/local_data_source.dart';
import 'package:daily_bread/data/models/user_model.dart';
import 'package:daily_bread/data/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _InMemoryLocalDataSource dataSource;
  late DateTime currentTime;
  late UserRepository repository;

  setUp(() {
    dataSource = _InMemoryLocalDataSource();
    currentTime = DateTime(2024, 1, 1);
    repository = UserRepository(dataSource, nowProvider: () => currentTime);
  });

  group('markChapterAsRead', () {
    test('initial read sets streak, XP, and first_read badge', () async {
      final updated = await repository.markChapterAsRead('Genesis', 1);

      expect(updated.currentStreak, 1);
      expect(updated.totalXp, AppConstants.xpPerChapter);
      expect(updated.badges, contains('first_read'));
      expect(updated.readingProgress['Genesis'], contains(1));
    });

    test('consecutive day increments streak and awards streak XP', () async {
      await repository.markChapterAsRead('Genesis', 1);
      currentTime = currentTime.add(const Duration(days: 1));

      final updated = await repository.markChapterAsRead('Exodus', 1);

      expect(updated.currentStreak, 2);
      final expectedXp =
          (AppConstants.xpPerChapter * 2) + (AppConstants.xpPerDayStreak * 2);
      expect(updated.totalXp, expectedXp);
      expect(updated.longestStreak, 2);
    });

    test('streak day 7 grants bonus XP and streak badge', () async {
      dataSource.seedUser(
        UserModel(
          currentStreak: 6,
          longestStreak: 6,
          totalXp: 500,
          level: 3,
          badges: [],
          lastReadDate: currentTime.subtract(const Duration(days: 1)),
          readingProgress: {
            'Genesis': {1, 2, 3, 4, 5, 6},
          },
        ),
      );

      final updated = await repository.markChapterAsRead('Genesis', 7);

      final expectedGain =
          AppConstants.xpPerChapter +
          (AppConstants.xpPerDayStreak * 7) +
          AppConstants.streakBonus7Days;
      expect(updated.totalXp, 500 + expectedGain);
      expect(updated.currentStreak, 7);
      expect(updated.badges, contains('streak_7'));
    });

    test('missing more than one day resets streak without freeze', () async {
      dataSource.seedUser(
        UserModel(
          currentStreak: 5,
          longestStreak: 8,
          totalXp: 200,
          level: 2,
          lastReadDate: currentTime.subtract(const Duration(days: 2)),
          readingProgress: {
            'Genesis': {1, 2, 3, 4, 5},
          },
          streakFreezes: 0,
        ),
      );

      final updated = await repository.markChapterAsRead('Exodus', 1);

      expect(updated.currentStreak, 1);
      expect(updated.longestStreak, 8);
      expect(updated.totalXp, 200 + AppConstants.xpPerChapter);
      expect(updated.streakFreezes, 0);
    });

    test('streak freeze preserves streak and consumes one freeze', () async {
      dataSource.seedUser(
        UserModel(
          currentStreak: 5,
          longestStreak: 5,
          totalXp: 200,
          level: 2,
          lastReadDate: currentTime.subtract(const Duration(days: 2)),
          readingProgress: {
            'Genesis': {1, 2, 3, 4, 5},
          },
          streakFreezes: 1,
        ),
      );

      final updated = await repository.markChapterAsRead('Exodus', 1);

      expect(updated.currentStreak, 6);
      expect(
        updated.totalXp,
        200 + AppConstants.xpPerChapter + (AppConstants.xpPerDayStreak * 6),
      );
      expect(updated.streakFreezes, 0);
    });

    test('adds bookworm badge after reading 20 chapters in one book', () async {
      dataSource.seedUser(
        UserModel(
          currentStreak: 1,
          longestStreak: 1,
          totalXp: 300,
          level: 3,
          lastReadDate: currentTime,
          readingProgress: {
            'Genesis': {
              1,
              2,
              3,
              4,
              5,
              6,
              7,
              8,
              9,
              10,
              11,
              12,
              13,
              14,
              15,
              16,
              17,
              18,
              19,
            },
          },
        ),
      );

      final updated = await repository.markChapterAsRead('Genesis', 20);

      expect(updated.badges, contains('bookworm'));
    });

    test('adds xp_1000 badge when crossing 1000 total XP', () async {
      dataSource.seedUser(
        UserModel(
          currentStreak: 1,
          longestStreak: 1,
          totalXp: 995,
          level: 4,
          lastReadDate: currentTime,
          readingProgress: {
            'Genesis': {1},
          },
        ),
      );

      final updated = await repository.markChapterAsRead('Genesis', 2);

      expect(updated.totalXp, greaterThanOrEqualTo(1000));
      expect(updated.badges, contains('xp_1000'));
    });
  });
}

class _InMemoryLocalDataSource implements LocalDataSource {
  UserModel _user = UserModel();
  String? _activePlanId;

  void seedUser(UserModel user) {
    _user = user;
  }

  @override
  Future<void> clearUser() async {
    _user = UserModel();
  }

  @override
  Future<UserModel> getUser() async {
    return _user;
  }

  @override
  Future<void> saveUser(UserModel user) async {
    _user = user;
  }

  @override
  Future<void> clearActivePlanId() async {
    _activePlanId = null;
  }

  @override
  String? getActivePlanId() {
    return _activePlanId;
  }

  @override
  Future<void> saveActivePlanId(String planId) async {
    _activePlanId = planId;
  }
}
