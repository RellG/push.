import 'package:flutter/material.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/repositories/date_key.dart';

class HeatmapCalendar extends StatelessWidget {
  const HeatmapCalendar({
    required this.days,
    required this.today,
    required this.onDaySelected,
    super.key,
  });

  final List<DayLog> days;
  final DateTime today;
  final ValueChanged<DayLog?> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dayByDate = {
      for (final day in days) day.date: day,
    };
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(const Duration(days: 364));
    final leadingBlanks = start.weekday % 7;
    final cells = <_HeatmapCellData>[
      for (var index = 0; index < leadingBlanks; index += 1)
        const _HeatmapCellData.empty(),
      for (var index = 0; index < 365; index += 1)
        _HeatmapCellData.forDate(
          start.add(Duration(days: index)),
          dayByDate,
        ),
    ];
    final weeks = <List<_HeatmapCellData>>[
      for (var index = 0; index < cells.length; index += 7)
        cells.skip(index).take(7).toList(),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final week in weeks)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                children: [
                  for (final cell in week)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _HeatmapCell(
                        data: cell,
                        color: _colorForCell(colors, cell.day),
                        onTap: () => onDaySelected(cell.day),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _colorForCell(PushColorTokens colors, DayLog? day) {
    if (day == null) {
      return colors.surfaceAlt;
    }

    final ratio = day.goal <= 0 ? 0.0 : (day.totalReps / day.goal).clamp(0, 1);
    if (ratio == 0) {
      return colors.surfaceAlt;
    }
    if (ratio < 0.34) {
      return Color.lerp(colors.surfaceAlt, colors.accentStart, 0.35)!;
    }
    if (ratio < 0.67) {
      return Color.lerp(colors.accentStart, colors.accentMid, 0.45)!;
    }
    if (ratio < 1) {
      return Color.lerp(colors.accentMid, colors.accentEnd, 0.55)!;
    }
    return colors.textPrimary;
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({
    required this.data,
    required this.color,
    required this.onTap,
  });

  final _HeatmapCellData data;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.square(dimension: 12);
    }

    return Semantics(
      button: true,
      label: data.day == null
          ? '${data.date}: no pushups logged'
          : '${data.date}: ${data.day!.totalReps} pushups',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: const SizedBox.square(dimension: 12),
        ),
      ),
    );
  }
}

class _HeatmapCellData {
  const _HeatmapCellData.empty() : date = '', day = null, isEmpty = true;

  _HeatmapCellData.forDate(
    DateTime dateTime,
    Map<String, DayLog> dayByDate,
  ) : date = localDateKey(dateTime),
      day = dayByDate[localDateKey(dateTime)],
      isEmpty = false;

  final String date;
  final DayLog? day;
  final bool isEmpty;
}
