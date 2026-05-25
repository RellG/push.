import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/typography.dart';
import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/presentation/widgets/app_bottom_nav.dart';
import 'package:push_app/presentation/widgets/heatmap_calendar.dart';
import 'package:push_app/providers/app_providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(allDaysProvider);
    final today = ref.watch(clockProvider)();

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'History',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 24),
                days.when(
                  data: (value) => HeatmapCalendar(
                    days: value,
                    today: today,
                    onDaySelected: (day) => _showDay(context, day),
                  ),
                  error: (error, stackTrace) => Text(error.toString()),
                  loading: () => const SizedBox(
                    height: 160,
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

  void _showDay(BuildContext context, DayLog? day) {
    final colors = context.colors;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.surface,
        showDragHandle: true,
        builder: (context) {
          if (day == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No pushups logged.'),
            );
          }

          final ratio = day.goal <= 0 ? 0 : day.totalReps / day.goal;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.date, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Text(
                  day.totalReps.toString(),
                  style: PushTypography.monoNumber(
                    color: colors.textPrimary,
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(ratio * 100).round()}% of ${day.goal}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
