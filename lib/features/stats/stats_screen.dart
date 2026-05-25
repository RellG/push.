import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/typography.dart';
import 'package:push_app/domain/models/chart_point.dart';
import 'package:push_app/domain/models/push_stats.dart';
import 'package:push_app/presentation/widgets/app_bottom_nav.dart';
import 'package:push_app/providers/app_providers.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  _StatsRange _range = _StatsRange.seven;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Stats', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 24),
                stats.when(
                  data: _buildStats,
                  error: (error, stackTrace) => Text(error.toString()),
                  loading: () => const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats(PushStats stats) {
    final points = switch (_range) {
      _StatsRange.seven => stats.last7Days,
      _StatsRange.thirty => stats.last30Days,
      _StatsRange.ninety => stats.last90Days,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.45,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(label: 'Total', value: stats.totalPushups.toString()),
            _StatCard(label: 'Longest', value: '${stats.longestStreak}d'),
            _StatCard(
              label: 'Weekly avg',
              value: stats.weeklyAverage.toStringAsFixed(1),
            ),
            _StatCard(label: 'Max set', value: stats.maxSingleSet.toString()),
          ],
        ),
        const SizedBox(height: 24),
        SegmentedButton<_StatsRange>(
          selected: {_range},
          onSelectionChanged: (value) => setState(() => _range = value.single),
          segments: const [
            ButtonSegment(value: _StatsRange.seven, label: Text('7D')),
            ButtonSegment(value: _StatsRange.thirty, label: Text('30D')),
            ButtonSegment(value: _StatsRange.ninety, label: Text('90D')),
          ],
        ),
        const SizedBox(height: 16),
        _LineChart(points: points),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.textMuted),
            ),
            Text(
              value,
              style: PushTypography.monoNumber(
                color: colors.textPrimary,
                fontSize: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points});

  final List<ChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxY = points.fold<double>(
      10,
      (max, point) => point.value > max ? point.value.toDouble() : max,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        height: 240,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 24, 24, 12),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: points.isEmpty ? 0 : (points.length - 1).toDouble(),
              minY: 0,
              maxY: maxY * 1.15,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colors.border,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => colors.surfaceAlt,
                  getTooltipItems: (spots) {
                    return [
                      for (final spot in spots)
                        LineTooltipItem(
                          spot.y.round().toString(),
                          PushTypography.monoNumber(
                            color: colors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                    ];
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var index = 0; index < points.length; index += 1)
                      FlSpot(index.toDouble(), points[index].value.toDouble()),
                  ],
                  isCurved: true,
                  color: colors.textPrimary,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.textPrimary.withValues(alpha: 0.22),
                        colors.textPrimary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _StatsRange { seven, thirty, ninety }
