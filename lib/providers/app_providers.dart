import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';

const onboardingCompleteKey = 'onboarding_complete';

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Emits the current local-day key, re-emitting whenever the clock crosses
/// into a new day. Polls every 30s so a set logged just after midnight lands
/// in the correct [DayLog] bucket. Consumers can also invalidate this provider
/// directly (e.g., on `AppLifecycleState.resumed`) to refresh immediately.
final todayDateProvider = StreamProvider<String>((ref) async* {
  final clock = ref.watch(clockProvider);
  var last = localDateKey(clock());
  yield last;
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 30))) {
    final next = localDateKey(clock());
    if (next != last) {
      last = next;
      yield next;
    }
  }
});

final databaseProvider = FutureProvider<Database>((ref) {
  return openPushDatabase();
});

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return preferences.getBool(onboardingCompleteKey) ?? false;
});

final profileRepositoryProvider = FutureProvider<ProfileRepository>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  return ProfileRepository(database);
});

final dayRepositoryProvider = FutureProvider<DayRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return DayRepository(database);
});

final setRepositoryProvider = FutureProvider<SetRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return SetRepository(database);
});

final profileProvider = StreamProvider<Profile?>((ref) async* {
  final repository = await ref.watch(profileRepositoryProvider.future);
  yield* repository.watchProfile();
});

/// Theme picked during onboarding so the choice previews immediately,
/// before a profile exists. Ignored once a profile is saved.
final onboardingThemePreviewProvider = StateProvider<String?>((ref) => null);

ThemeMode _themeModeFromKey(String? key) => switch (key) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

final themeModeProvider = Provider<ThemeMode>((ref) {
  final preview = ref.watch(onboardingThemePreviewProvider);
  final profile = ref.watch(profileProvider);
  return profile.maybeWhen(
    data: (value) => _themeModeFromKey(value?.themeMode ?? preview),
    orElse: () => _themeModeFromKey(preview),
  );
});

typedef CompleteOnboarding =
    Future<void> Function({
      required String name,
      required int currentGoal,
      required String themeMode,
    });

final completeOnboardingProvider = Provider<CompleteOnboarding>((ref) {
  return ({
    required String name,
    required int currentGoal,
    required String themeMode,
  }) async {
    final profileRepository = await ref.read(profileRepositoryProvider.future);
    final preferences = await ref.read(sharedPreferencesProvider.future);

    await profileRepository.saveProfile(
      name: name,
      currentGoal: currentGoal,
      themeMode: themeMode,
    );
    await preferences.setBool(onboardingCompleteKey, true);
    ref.invalidate(onboardingCompleteProvider);
  };
});

final todayProvider = StreamProvider<DayLog?>((ref) async* {
  final repository = await ref.watch(dayRepositoryProvider.future);
  final date = await ref.watch(todayDateProvider.future);
  yield* repository.watchByDate(date);
});

final todaySetsProvider = FutureProvider<List<PushupSet>>((ref) async {
  final day = await ref.watch(todayProvider.future);
  if (day == null) {
    return <PushupSet>[];
  }

  final repository = await ref.watch(setRepositoryProvider.future);
  return repository.findSetsForDay(day);
});

typedef LogSet =
    Future<void> Function({
      required int reps,
      String? note,
    });

final logSetProvider = Provider<LogSet>((ref) {
  return ({required int reps, String? note}) async {
    final profileRepository = await ref.read(profileRepositoryProvider.future);
    final setRepository = await ref.read(setRepositoryProvider.future);
    final profile = await profileRepository.getProfile();
    if (profile == null) {
      throw StateError('Cannot log a set before onboarding is complete.');
    }

    await setRepository.addSet(
      reps: reps,
      loggedAt: ref.read(clockProvider)(),
      dailyGoal: profile.currentGoal,
      note: note,
    );
    ref
      ..invalidate(todayProvider)
      ..invalidate(todaySetsProvider)
      ..invalidate(allDaysProvider)
      ..invalidate(allSetsProvider);
  };
});

final exportJsonProvider = Provider<Future<String> Function()>((ref) {
  return () async {
    final database = await ref.read(databaseProvider.future);
    final profileSnapshot = await profileStore.findFirst(database);
    final profile = profileSnapshot == null
        ? null
        : Profile.fromMap(profileSnapshot.key, profileSnapshot.value);
    final days = [
      for (final snapshot in await dayLogStore.find(
        database,
        finder: Finder(sortOrders: [SortOrder('date')]),
      ))
        DayLog.fromMap(snapshot.key, snapshot.value),
    ];
    final sets = [
      for (final snapshot in await pushupSetStore.find(
        database,
        finder: Finder(sortOrders: [SortOrder('loggedAt')]),
      ))
        PushupSet.fromMap(snapshot.key, snapshot.value),
    ];

    return const JsonEncoder.withIndent('  ').convert({
      'profile': profile == null
          ? null
          : {
              'name': profile.name,
              'currentGoal': profile.currentGoal,
              'themeMode': profile.themeMode,
              'createdAt': profile.createdAt.toIso8601String(),
            },
      'days': [
        for (final day in days)
          {
            'date': day.date,
            'goal': day.goal,
            'totalReps': day.totalReps,
            'completedAt': day.completedAt?.toIso8601String(),
            'setIds': day.setIds,
          },
      ],
      'sets': [
        for (final set in sets)
          {
            'id': set.id,
            'reps': set.reps,
            'loggedAt': set.loggedAt.toIso8601String(),
            'note': set.note,
          },
      ],
    });
  };
});

final seedDemoDataProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final database = await ref.read(databaseProvider.future);
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);

    await database.transaction((txn) async {
      final existingProfile = await profileStore.findFirst(txn);
      if (existingProfile == null) {
        final profile = Profile()
          ..name = 'Demo'
          ..currentGoal = 100
          ..themeMode = 'dark'
          ..createdAt = now;
        await profileStore.add(txn, profile.toMap());
      }

      for (var offset = 0; offset < 90; offset += 1) {
        final date = today.subtract(Duration(days: offset));
        final key = localDateKey(date);
        final existingDay = await dayLogStore.findFirst(
          txn,
          finder: Finder(filter: Filter.equals('date', key)),
        );
        if (existingDay != null) {
          continue;
        }

        final reps = offset % 6 == 0 ? 0 : 45 + ((offset * 17) % 95);
        final setIds = <int>[];
        if (reps > 0) {
          final set = PushupSet()
            ..reps = reps
            ..loggedAt = DateTime(date.year, date.month, date.day, 12);
          set.id = await pushupSetStore.add(txn, set.toMap());
          setIds.add(set.id);
        }

        final day = DayLog()
          ..date = key
          ..goal = 100
          ..totalReps = reps
          ..setIds = setIds
          ..completedAt = reps >= 100
              ? DateTime(date.year, date.month, date.day, 12)
              : null;
        await dayLogStore.add(txn, day.toMap());
      }
    });

    ref
      ..invalidate(profileProvider)
      ..invalidate(todayProvider)
      ..invalidate(todaySetsProvider)
      ..invalidate(allDaysProvider)
      ..invalidate(allSetsProvider);
  };
});

final allDaysProvider = StreamProvider<List<DayLog>>((ref) async* {
  final database = await ref.watch(databaseProvider.future);
  yield* dayLogStore.query().onSnapshots(database).map(
        (snapshots) => [
          for (final snapshot in snapshots)
            DayLog.fromMap(snapshot.key, snapshot.value),
        ],
      );
});

final allSetsProvider = StreamProvider<List<PushupSet>>((ref) async* {
  final database = await ref.watch(databaseProvider.future);
  yield* pushupSetStore.query().onSnapshots(database).map(
        (snapshots) => [
          for (final snapshot in snapshots)
            PushupSet.fromMap(snapshot.key, snapshot.value),
        ],
      );
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
