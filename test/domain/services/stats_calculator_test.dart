import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/db/entities/pushup_set.dart';
import 'package:push_app/domain/services/stats_calculator.dart';

void main() {
  const calculator = StatsCalculator();

  test('calculates totals, longest streak, max set, and chart ranges', () {
    final stats = calculator.calculate(
      days: [
        _day('2026-05-23', totalReps: 50, goal: 100, completed: false),
        _day('2026-05-24', totalReps: 100, goal: 100),
        _day('2026-05-25', totalReps: 120, goal: 100),
      ],
      sets: [
        _set(50),
        _set(80),
        _set(40),
      ],
      today: DateTime(2026, 5, 25, 20),
    );

    expect(stats.totalPushups, 270);
    expect(stats.longestStreak, 2);
    expect(stats.weeklyAverage, closeTo(270 / 7, 0.001));
    expect(stats.maxSingleSet, 80);
    expect(stats.last7Days, hasLength(7));
    expect(stats.last30Days, hasLength(30));
    expect(stats.last90Days, hasLength(90));
    expect(stats.last7Days.last.date, '2026-05-25');
    expect(stats.last7Days.last.value, 120);
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

PushupSet _set(int reps) {
  return PushupSet()
    ..reps = reps
    ..loggedAt = DateTime(2026, 5, 25);
}
