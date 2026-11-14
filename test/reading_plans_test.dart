import 'package:daily_bread/core/constants/reading_plans.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('built-in plan descriptions match their ordered readings', () {
    expect(ReadingPlans.all.map((plan) => plan.id), [
      'gospels_30',
      'john_21',
      'wisdom_14',
    ]);

    final gospels = ReadingPlans.all[0];
    expect(gospels.title, 'Matthew and the Beginning of Mark in 30 Days');
    expect(
      gospels.description,
      'Read Matthew 1–28 and Mark 1–2, one chapter a day.',
    );
    expect(gospels.totalDays, 30);
    expect(gospels.chapters.map((reference) => reference.id), [
      for (var chapter = 1; chapter <= 28; chapter++) 'Matthew:$chapter',
      for (var chapter = 1; chapter <= 2; chapter++) 'Mark:$chapter',
    ]);

    final john = ReadingPlans.all[1];
    expect(john.title, 'Gospel of John in 21 Days');
    expect(
      john.description,
      'One chapter a day through John for clarity and depth.',
    );
    expect(john.totalDays, 21);
    expect(john.chapters.map((reference) => reference.id), [
      for (var chapter = 1; chapter <= 21; chapter++) 'John:$chapter',
    ]);

    final wisdom = ReadingPlans.all[2];
    expect(wisdom.title, 'Wisdom in 14 Days');
    expect(
      wisdom.description,
      'Read Psalms 1–10 and Proverbs 1–4, one chapter a day.',
    );
    expect(wisdom.totalDays, 14);
    expect(wisdom.chapters.map((reference) => reference.id), [
      for (var chapter = 1; chapter <= 10; chapter++) 'Psalms:$chapter',
      for (var chapter = 1; chapter <= 4; chapter++) 'Proverbs:$chapter',
    ]);
  });
}
