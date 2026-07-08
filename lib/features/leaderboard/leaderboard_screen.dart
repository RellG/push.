import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:push_app/app/router.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/typography.dart';
import 'package:push_app/data/db/entities/leaderboard_entry.dart';
import 'package:push_app/presentation/widgets/app_bottom_nav.dart';
import 'package:push_app/providers/app_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(leaderboardSyncProvider);
    final board = ref.watch(leaderboardProvider);
    final uid = ref.watch(authUserChangesProvider).valueOrNull?.uid;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Leaderboard',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () => context.push(AppRoutes.settings),
                      icon: const Icon(LucideIcons.settings),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                board.when(
                  data: (entries) => _Board(entries: entries, uid: uid),
                  error: (error, stackTrace) =>
                      const Text('Unable to load — check your connection.'),
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
}

class _Board extends StatelessWidget {
  const _Board({
    required this.entries,
    required this.uid,
  });

  final List<LeaderboardEntry> entries;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (entries.isEmpty) {
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
              Text(
                'No one on the board yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Log a set and you will show up here.',
                style: TextStyle(color: colors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final (index, entry) in entries.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          _BoardRow(
            rank: index + 1,
            entry: entry,
            isSelf: entry.id == uid,
          ),
        ],
      ],
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({
    required this.rank,
    required this.entry,
    required this.isSelf,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: isSelf ? colors.accentMid : colors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#$rank',
                style: PushTypography.monoNumber(
                  color: rank <= 3 ? colors.textPrimary : colors.textMuted,
                  fontSize: 14,
                  fontWeight: rank <= 3 ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSelf ? '${entry.name} (you)' : entry.name,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.flame,
                        size: 13,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${entry.currentStreak}d',
                        style: PushTypography.monoNumber(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'today ',
                        style:
                            TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                      Text(
                        '${entry.todayReps}',
                        style: PushTypography.monoNumber(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${entry.totalReps}',
              style: PushTypography.monoNumber(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
