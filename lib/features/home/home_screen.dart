import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/typography.dart';
import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/db/entities/pushup_set.dart';
import 'package:push_app/presentation/widgets/app_bottom_nav.dart';
import 'package:push_app/presentation/widgets/goal_celebration_layer.dart';
import 'package:push_app/presentation/widgets/progress_ring.dart';
import 'package:push_app/presentation/widgets/quick_add_row.dart';
import 'package:push_app/providers/app_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _celebrationKey = GlobalKey<GoalCelebrationLayerState>();
  var _hasSeenToday = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DayLog?>>(todayProvider, (previous, next) {
      final day = next.valueOrNull;
      if (day == null) {
        return;
      }

      final wasComplete = previous?.valueOrNull?.completedAt != null;
      final isComplete = day.completedAt != null;
      if (_hasSeenToday && !wasComplete && isComplete) {
        _celebrationKey.currentState?.play();
      }
      _hasSeenToday = true;
    });

    final profile = ref.watch(profileProvider);
    final today = ref.watch(todayProvider);
    final sets = ref.watch(todaySetsProvider);
    final streak = ref.watch(streakProvider);

    final goal = profile.maybeWhen(
      data: (value) => value?.currentGoal,
      orElse: () => null,
    );

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref
                      ..invalidate(todayDateProvider)
                      ..invalidate(allDaysProvider)
                      ..invalidate(allSetsProvider)
                      ..invalidate(todayProvider)
                      ..invalidate(todaySetsProvider);
                    await ref.read(todayProvider.future);
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: _HomeHeader(streak: streak),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: today.when(
                            data: (day) => _ProgressSection(
                              day: day,
                              goal: day?.goal ?? goal ?? 100,
                            ),
                            error: (error, stackTrace) => _MessageState(
                              title: 'Unable to load today',
                              detail: error.toString(),
                            ),
                            loading: () => const _LoadingBlock(height: 248),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                          child: QuickAddRow(
                            onAdd: (reps) =>
                                ref.read(logSetProvider)(reps: reps),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        sliver: sets.when(
                          data: (value) => _SetsList(sets: value),
                          error: (error, stackTrace) => SliverToBoxAdapter(
                            child: _MessageState(
                              title: 'Unable to load sets',
                              detail: error.toString(),
                            ),
                          ),
                          loading: () => const SliverToBoxAdapter(
                            child: _LoadingBlock(height: 160),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          GoalCelebrationLayer(key: _celebrationKey),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.streak});

  final AsyncValue<int> streak;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(child: Text('Push.', style: textTheme.headlineMedium)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            streak.when(
              data: (value) => '${value}d',
              error: (error, stackTrace) => '0d',
              loading: () => '--d',
            ),
            style: PushTypography.monoNumber(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.day,
    required this.goal,
  });

  final DayLog? day;
  final int goal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ProgressRing(
        current: day?.totalReps ?? 0,
        goal: goal,
      ),
    );
  }
}

class _SetsList extends StatelessWidget {
  const _SetsList({required this.sets});

  final List<PushupSet> sets;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    if (sets.isEmpty) {
      return const SliverToBoxAdapter(
        child: _MessageState(
          title: 'No sets yet',
          detail: 'Log the first set for today.',
        ),
      );
    }

    return SliverList.separated(
      itemCount: sets.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final set = sets[index];
        final time = TimeOfDay.fromDateTime(set.loggedAt).format(context);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    time,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
                Text(
                  set.reps.toString(),
                  style: PushTypography.monoNumber(
                    color: colors.textPrimary,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              detail,
              style: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
