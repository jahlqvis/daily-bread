import '../datasources/local_data_source.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class UserRepository {
  final LocalDataSource _localDataSource;
  final DateTime Function() _nowProvider;
  Future<void> _pendingWrite = Future<void>.value();

  UserRepository(this._localDataSource, {DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  Future<UserModel> getUser() => _localDataSource.getUser();

  Future<T> _serializeWrite<T>(Future<T> Function() operation) {
    final result = _pendingWrite.then((_) => operation());
    _pendingWrite = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<UserModel> markChapterAsRead(String book, int chapter) =>
      _serializeWrite(() => _markChapterAsRead(book, chapter));

  Future<UserModel> _markChapterAsRead(String book, int chapter) async {
    final user = await getUser();
    if (user.readingProgress[book]?.contains(chapter) ?? false) {
      return user;
    }
    final now = _nowProvider();
    // Compare calendar dates rather than local midnight durations: daylight
    // saving transitions can make consecutive local days 23 or 25 hours long.
    final today = DateTime.utc(now.year, now.month, now.day);

    final progress = user.readingProgress.map(
      (book, chapters) => MapEntry(book, {...chapters}),
    );
    progress.putIfAbsent(book, () => {});
    progress[book]!.add(chapter);

    int newStreak = user.currentStreak;
    int xpGained = AppConstants.xpPerChapter;
    int newStreakFreezes = user.streakFreezes;

    if (user.lastReadDate == null) {
      newStreak = 1;
    } else {
      final lastRead = DateTime.utc(
        user.lastReadDate!.year,
        user.lastReadDate!.month,
        user.lastReadDate!.day,
      );
      final difference = today.difference(lastRead).inDays;

      if (difference <= 0) {
      } else if (difference == 1) {
        newStreak = user.currentStreak + 1;
        xpGained += AppConstants.xpPerDayStreak * newStreak;
      } else {
        if (user.streakFreezes > 0 && difference == 2) {
          newStreak = user.currentStreak + 1;
          xpGained += AppConstants.xpPerDayStreak * newStreak;
          newStreakFreezes = user.streakFreezes - 1;
        } else {
          newStreak = 1;
        }
      }
    }

    // A milestone bonus is earned only when the streak reaches that value,
    // not for every additional chapter read on the same day.
    if (newStreak == 7 && newStreak > user.currentStreak) {
      xpGained += AppConstants.streakBonus7Days;
    } else if (newStreak == 30 && newStreak > user.currentStreak) {
      xpGained += AppConstants.streakBonus30Days;
    } else if (newStreak == 100 && newStreak > user.currentStreak) {
      xpGained += AppConstants.streakBonus100Days;
    }

    final newTotalXp = user.totalXp + xpGained;
    final newLevel = _calculateLevel(newTotalXp);
    final newLongestStreak = newStreak > user.longestStreak
        ? newStreak
        : user.longestStreak;

    final badges = List<String>.from(user.badges);
    _checkAndAddBadges(badges, newStreak, progress, newTotalXp, newLevel);
    if (newStreakFreezes < user.streakFreezes &&
        !badges.contains('streak_freeze')) {
      badges.add('streak_freeze');
    }

    final updatedUser = user.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongestStreak,
      totalXp: newTotalXp,
      level: newLevel,
      badges: badges,
      lastReadDate:
          user.lastReadDate != null && now.isBefore(user.lastReadDate!)
          ? user.lastReadDate
          : now,
      readingProgress: progress,
      streakFreezes: newStreakFreezes,
    );

    await _localDataSource.saveUser(updatedUser);
    return updatedUser;
  }

  int _calculateLevel(int xp) {
    int level = 1;
    for (final entry in AppConstants.levelThresholds.entries) {
      if (xp >= entry.value) {
        level = entry.key;
      }
    }
    return level;
  }

  void _checkAndAddBadges(
    List<String> badges,
    int streak,
    Map<String, Set<int>> progress,
    int totalXp,
    int level,
  ) {
    if (!badges.contains('first_read') &&
        progress.values.any((chapters) => chapters.isNotEmpty)) {
      badges.add('first_read');
    }
    if (!badges.contains('streak_7') && streak >= 7) {
      badges.add('streak_7');
    }
    if (!badges.contains('streak_30') && streak >= 30) {
      badges.add('streak_30');
    }
    if (!badges.contains('streak_100') && streak >= 100) {
      badges.add('streak_100');
    }
    if (!badges.contains('level_5') && level >= 5) {
      badges.add('level_5');
    }
    if (!badges.contains('level_10') && level >= 10) {
      badges.add('level_10');
    }
    if (!badges.contains('bookworm') && _hasCompletedBook(progress)) {
      badges.add('bookworm');
    }
    if (!badges.contains('xp_1000') && totalXp >= 1000) {
      badges.add('xp_1000');
    }
  }

  bool _hasCompletedBook(Map<String, Set<int>> progress) {
    for (final entry in progress.entries) {
      final chapterCount = AppConstants.chaptersPerBook[entry.key];
      if (chapterCount == null || entry.value.length < chapterCount) continue;
      var complete = true;
      for (var chapter = 1; chapter <= chapterCount; chapter++) {
        if (!entry.value.contains(chapter)) {
          complete = false;
          break;
        }
      }
      if (complete) return true;
    }
    return false;
  }

  Future<void> useStreakFreeze() => _serializeWrite(() async {
    final user = await getUser();
    if (user.streakFreezes > 0) {
      await _localDataSource.saveUser(
        user.copyWith(streakFreezes: user.streakFreezes - 1),
      );
    }
  });

  Future<void> resetUser() => _serializeWrite(_localDataSource.clearUser);
}
