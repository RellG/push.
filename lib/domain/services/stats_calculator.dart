import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/db/entities/pushup_set.dart';
import 'package:push_app/data/repositories/date_key.dart';
import 'package:push_app/domain/models/chart_point.dart';
import 'package:push_app/domain/models/push_stats.dart';
import 'package:push_app/domain/services/streak_calculator.dart';

class StatsCalculator {
  const StatsCalculator([
    this._streakCalculator = const StreakCalculator(),
  ]);

  final StreakCalculator _streakCalculator;

  PushStats calculate({
    required List<DayLog> days,
    required List<PushupSet> sets,
    required DateTime today,
  }) {
    final totalPushups = days.fold<int>(
      0,
      (total, day) => total + day.totalReps,
    );
    final maxSingleSet = sets.fold<int>(
      0,
      (max, set) => set.reps > max ? set.reps : max,
    );

    return PushStats(
      totalPushups: totalPushups,
      longestStreak: _streakCalculator.longestStreak(days),
      weeklyAverage: _averageForRange(days: days, today: today, dayCount: 7),
      maxSingleSet: maxSingleSet,
      last7Days: _pointsForRange(days: days, today: today, dayCount: 7),
      last30Days: _pointsForRange(days: days, today: today, dayCount: 30),
      last90Days: _pointsForRange(days: days, today: today, dayCount: 90),
    );
  }

  double _averageForRange({
    required List<DayLog> days,
    required DateTime today,
    required int dayCount,
  }) {
    final points = _pointsForRange(
      days: days,
      today: today,
      dayCount: dayCount,
    );
    if (points.isEmpty) {
      return 0;
    }

    final total = points.fold<int>(0, (sum, point) => sum + point.value);
    return total / dayCount;
  }

  List<ChartPoint> _pointsForRange({
    required List<DayLog> days,
    required DateTime today,
    required int dayCount,
  }) {
    final repsByDate = {
      for (final day in days) day.date: day.totalReps,
    };
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(Duration(days: dayCount - 1));

    return List<ChartPoint>.generate(dayCount, (index) {
      final date = start.add(Duration(days: index));
      final key = localDateKey(date);

      return ChartPoint(
        date: key,
        value: repsByDate[key] ?? 0,
      );
    });
  }
}
