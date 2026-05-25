import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

const onboardingCompleteKey = 'onboarding_complete';

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final todayDateProvider = Provider<String>((ref) {
  return localDateKey(ref.watch(clockProvider)());
});

final isarProvider = FutureProvider<Isar>((ref) {
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

final themeModeProvider = Provider<ThemeMode>((ref) {
  final profile = ref.watch(profileProvider);
  return profile.maybeWhen(
    data: (value) => switch (value?.themeMode) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    },
    orElse: () => ThemeMode.dark,
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
  final date = ref.watch(todayDateProvider);
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

    await setRepository.addSet(
      reps: reps,
      loggedAt: ref.read(clockProvider)(),
      dailyGoal: profile?.currentGoal ?? 100,
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
    final isar = await ref.read(isarProvider.future);
    final profile = await isar.profiles.where().findFirst();
    final days = await isar.dayLogs.where().sortByDate().findAll();
    final sets = await isar.pushupSets.where().sortByLoggedAt().findAll();

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
    final isar = await ref.read(isarProvider.future);
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);

    await isar.writeTxn(() async {
      final existingProfile = await isar.profiles.where().findFirst();
      if (existingProfile == null) {
        final profile = Profile()
          ..name = 'Demo'
          ..currentGoal = 100
          ..themeMode = 'dark'
          ..createdAt = now;
        await isar.profiles.put(profile);
      }

      for (var offset = 0; offset < 90; offset += 1) {
        final date = today.subtract(Duration(days: offset));
        final key = localDateKey(date);
        final existingDay = await isar.dayLogs.getByDate(key);
        if (existingDay != null) {
          continue;
        }

        final reps = offset % 6 == 0 ? 0 : 45 + ((offset * 17) % 95);
        final setIds = <int>[];
        if (reps > 0) {
          final set = PushupSet()
            ..reps = reps
            ..loggedAt = DateTime(date.year, date.month, date.day, 12);
          set.id = await isar.pushupSets.put(set);
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
        await isar.dayLogs.putByDate(day);
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
