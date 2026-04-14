import 'package:daily_bread/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson and fromJson preserve user model fields', () {
    final model = UserModel(
      currentStreak: 12,
      longestStreak: 20,
      totalXp: 1350,
      level: 6,
      badges: const ['first_read', 'streak_7', 'xp_1000'],
      lastReadDate: DateTime(2024, 2, 15, 10, 30),
      readingProgress: {
        'Genesis': {1, 2, 3},
        'John': {1},
      },
      streakFreezes: 2,
    );

    final decoded = UserModel.fromJson(model.toJson());

    expect(decoded.currentStreak, model.currentStreak);
    expect(decoded.longestStreak, model.longestStreak);
    expect(decoded.totalXp, model.totalXp);
    expect(decoded.level, model.level);
    expect(decoded.badges, model.badges);
    expect(decoded.lastReadDate, model.lastReadDate);
    expect(decoded.readingProgress, model.readingProgress);
    expect(decoded.streakFreezes, model.streakFreezes);
  });
}
