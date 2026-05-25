import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/domain/services/streak_calculator.dart';

void main() {
  const calculator = StreakCalculator();

  test('counts today when it is complete', () {
    final days = [
      _day('2026-05-23', totalReps: 100, goal: 100),
      _day('2026-05-24', totalReps: 100, goal: 100),
      _day('2026-05-25', totalReps: 100, goal: 100),
    ];

    final streak = calculator.currentStreak(days, DateTime(2026, 5, 25, 12));

    expect(streak, 3);
  });

  test('keeps the current streak alive before today is complete', () {
    final days = [
      _day('2026-05-23', totalReps: 100, goal: 100),
      _day('2026-05-24', totalReps: 100, goal: 100),
      _day('2026-05-25', totalReps: 40, goal: 100, completed: false),
    ];

    final streak = calculator.currentStreak(days, DateTime(2026, 5, 25, 12));

    expect(streak, 2);
  });

  test('stops at missed days', () {
    final days = [
      _day('2026-05-21', totalReps: 100, goal: 100),
      _day('2026-05-23', totalReps: 100, goal: 100),
      _day('2026-05-24', totalReps: 100, goal: 100),
    ];

    final streak = calculator.longestStreak(days);

    expect(streak, 2);
  });
}

DayLog _day(
  String date, {
  required int totalReps,
  required int goal,
  bool completed = true,
}) {
  return DayLog()
    ..date = date
    ..goal = goal
    ..totalReps = totalReps
    ..completedAt = completed ? DateTime.parse(date) : null;
}
