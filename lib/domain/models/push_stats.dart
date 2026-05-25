import 'package:push_app/domain/models/chart_point.dart';

class PushStats {
  const PushStats({
    required this.totalPushups,
    required this.longestStreak,
    required this.weeklyAverage,
    required this.maxSingleSet,
    required this.last7Days,
    required this.last30Days,
    required this.last90Days,
  });

  final int totalPushups;
  final int longestStreak;
  final double weeklyAverage;
  final int maxSingleSet;
  final List<ChartPoint> last7Days;
  final List<ChartPoint> last30Days;
  final List<ChartPoint> last90Days;

  static const empty = PushStats(
    totalPushups: 0,
    longestStreak: 0,
    weeklyAverage: 0,
    maxSingleSet: 0,
    last7Days: <ChartPoint>[],
    last30Days: <ChartPoint>[],
    last90Days: <ChartPoint>[],
  );
}
