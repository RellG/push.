import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/db/entities/profile.dart';
import 'package:push_app/data/db/entities/pushup_set.dart';
import 'package:push_app/data/db/push_database.dart';
import 'package:push_app/data/repositories/date_key.dart';
import 'package:push_app/data/repositories/day_repository.dart';
import 'package:push_app/data/repositories/profile_repository.dart';
import 'package:push_app/data/repositories/set_repository.dart';
import 'package:push_app/domain/models/push_stats.dart';
import 'package:push_app/domain/services/stats_calculator.dart';
import 'package:push_app/domain/services/streak_calculator.dart';

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final todayDateProvider = Provider<String>((ref) {
  return localDateKey(ref.watch(clockProvider)());
});

final isarProvider = FutureProvider<Isar>((ref) {
  return openPushDatabase();
});

final profileRepositoryProvider = FutureProvider<ProfileRepository>((
  ref,
) async {
  final isar = await ref.watch(isarProvider.future);
  return ProfileRepository(isar);
});

final dayRepositoryProvider = FutureProvider<DayRepository>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  return DayRepository(isar);
});

final setRepositoryProvider = FutureProvider<SetRepository>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  return SetRepository(isar);
});

final profileProvider = StreamProvider<Profile?>((ref) async* {
  final repository = await ref.watch(profileRepositoryProvider.future);
  yield* repository.watchProfile();
});

final todayProvider = StreamProvider<DayLog?>((ref) async* {
  final repository = await ref.watch(dayRepositoryProvider.future);
  final date = ref.watch(todayDateProvider);
  yield* repository.watchByDate(date);
});

final allDaysProvider = StreamProvider<List<DayLog>>((ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.dayLogs.where().watch(fireImmediately: true);
});

final allSetsProvider = StreamProvider<List<PushupSet>>((ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.pushupSets.where().watch(fireImmediately: true);
});

final streakCalculatorProvider = Provider<StreakCalculator>((ref) {
  return const StreakCalculator();
});

final statsCalculatorProvider = Provider<StatsCalculator>((ref) {
  return StatsCalculator(
    ref.watch(streakCalculatorProvider),
  );
});

final streakProvider = Provider<AsyncValue<int>>((ref) {
  final days = ref.watch(allDaysProvider);
  final calculator = ref.watch(streakCalculatorProvider);
  final today = ref.watch(clockProvider)();

  return days.whenData((value) => calculator.currentStreak(value, today));
});

final statsProvider = Provider<AsyncValue<PushStats>>((ref) {
  final days = ref.watch(allDaysProvider);
  final sets = ref.watch(allSetsProvider);
  final calculator = ref.watch(statsCalculatorProvider);
  final today = ref.watch(clockProvider)();

  return days.when(
    data: (dayLogs) => sets.whenData(
      (pushupSets) => calculator.calculate(
        days: dayLogs,
        sets: pushupSets,
        today: today,
      ),
    ),
    error: AsyncValue.error,
    loading: AsyncValue.loading,
  );
});
