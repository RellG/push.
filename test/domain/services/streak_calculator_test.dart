import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/domain/services/streak_calculator.dart';

void main() {
  const calculator = StreakCalculator();

  group('currentStreak', () {
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

    test('returns 0 for an empty list', () {
      expect(calculator.currentStreak(const [], DateTime(2026, 5, 25)), 0);
    });

    test('returns 0 when no days are complete and today is incomplete', () {
      final days = [
        _day('2026-05-24', totalReps: 20, goal: 100, completed: false),
        _day('2026-05-25', totalReps: 10, goal: 100, completed: false),
      ];

      expect(calculator.currentStreak(days, DateTime(2026, 5, 25, 12)), 0);
    });

    test('returns 1 when only today is complete', () {
      final days = [_day('2026-05-25', totalReps: 100, goal: 100)];

      expect(calculator.currentStreak(days, DateTime(2026, 5, 25, 12)), 1);
    });

    test('breaks when there is a missed day in the past', () {
      final days = [
        _day('2026-05-22', totalReps: 100, goal: 100),
        _day('2026-05-24', totalReps: 100, goal: 100),
        _day('2026-05-25', totalReps: 100, goal: 100),
      ];

      expect(calculator.currentStreak(days, DateTime(2026, 5, 25, 12)), 2);
    });
  });

  group('longestStreak', () {
    test('stops at missed days', () {
      final days = [
        _day('2026-05-21', totalReps: 100, goal: 100),
        _day('2026-05-23', totalReps: 100, goal: 100),
        _day('2026-05-24', totalReps: 100, goal: 100),
      ];

      expect(calculator.longestStreak(days), 2);
    });

    test('returns 0 for empty input', () {
      expect(calculator.longestStreak(const []), 0);
    });

    test('returns 1 for a single completed day', () {
      final days = [_day('2026-05-25', totalReps: 100, goal: 100)];

      expect(calculator.longestStreak(days), 1);
    });

    test('counts consecutive days across DST spring-forward', () {
      // US DST spring-forward 2026: March 8 (March 7 → March 8 loses an hour).
      // `inDays` truncates 23h to 0 and used to break this streak; the
      // calendar-day comparison must treat them as consecutive.
      final days = [
        _day('2026-03-06', totalReps: 100, goal: 100),
        _day('2026-03-07', totalReps: 100, goal: 100),
        _day('2026-03-08', totalReps: 100, goal: 100),
        _day('2026-03-09', totalReps: 100, goal: 100),
      ];

      expect(calculator.longestStreak(days), 4);
    });

    test('counts consecutive days across DST fall-back', () {
      // US DST fall-back 2026: November 1 (gains an hour).
      final days = [
        _day('2026-10-31', totalReps: 100, goal: 100),
        _day('2026-11-01', totalReps: 100, goal: 100),
        _day('2026-11-02', totalReps: 100, goal: 100),
      ];

      expect(calculator.longestStreak(days), 3);
    });
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
