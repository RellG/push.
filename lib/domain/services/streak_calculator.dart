import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/repositories/date_key.dart';

class StreakCalculator {
  const StreakCalculator();

  int currentStreak(List<DayLog> days, DateTime today) {
    final completedDates = _completedDateSet(days);
    var cursor = _dateOnly(today);

    if (!completedDates.contains(localDateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (completedDates.contains(localDateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  int longestStreak(List<DayLog> days) {
    final completedDates = _completedDateSet(days).toList()..sort();
    if (completedDates.isEmpty) {
      return 0;
    }

    var longest = 1;
    var current = 1;
    var previous = DateTime.parse(completedDates.first);

    for (final date in completedDates.skip(1)) {
      final parsed = DateTime.parse(date);
      final expectedNext = DateTime(
        previous.year,
        previous.month,
        previous.day + 1,
      );
      final isConsecutive = parsed.year == expectedNext.year &&
          parsed.month == expectedNext.month &&
          parsed.day == expectedNext.day;
      if (isConsecutive) {
        current += 1;
      } else {
        current = 1;
      }
      if (current > longest) {
        longest = current;
      }
      previous = parsed;
    }

    return longest;
  }

  Set<String> _completedDateSet(List<DayLog> days) {
    return days
        .where((day) => day.completedAt != null || day.totalReps >= day.goal)
        .map((day) => day.date)
        .toSet();
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
