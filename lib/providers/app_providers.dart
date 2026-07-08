import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/db/entities/leaderboard_entry.dart';
import 'package:push_app/data/db/entities/profile.dart';
import 'package:push_app/data/db/entities/pushup_set.dart';
import 'package:push_app/data/firestore/legacy_migration.dart';
import 'package:push_app/data/firestore/user_firestore.dart';
import 'package:push_app/data/repositories/date_key.dart';
import 'package:push_app/data/repositories/day_repository.dart';
import 'package:push_app/data/repositories/leaderboard_repository.dart';
import 'package:push_app/data/repositories/profile_repository.dart';
import 'package:push_app/data/repositories/set_repository.dart';
import 'package:push_app/domain/models/push_stats.dart';
import 'package:push_app/domain/services/stats_calculator.dart';
import 'package:push_app/domain/services/streak_calculator.dart';
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

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// The anonymous Firebase user backing this install. Signs in on first
/// launch (requires network once); afterwards the same account is restored
/// from local storage, including offline.
final signedInUserProvider = FutureProvider<User>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final existing = auth.currentUser;
  if (existing != null) {
    return existing;
  }

  final credential = await auth.signInAnonymously();
  return credential.user!;
});

/// Live auth state, including provider-link changes (e.g. right after
/// linking Google), which `authStateChanges` alone would not emit.
final authUserChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).userChanges();
});

enum GoogleAuthResult { success, canceled, accountAlreadyLinked, failed }

const _googleAuthCancelCodes = {
  'popup-closed-by-user',
  'cancelled-popup-request',
  'user-cancelled',
  'web-context-cancelled',
  'web-context-canceled',
  'canceled',
};

/// Attaches a Google identity to the current anonymous user. The uid — and
/// therefore every Firestore document — stays exactly the same.
final linkGoogleAccountProvider =
    Provider<Future<GoogleAuthResult> Function()>((ref) {
  return () async {
    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;
    if (user == null) {
      return GoogleAuthResult.failed;
    }

    try {
      if (kIsWeb) {
        await user.linkWithPopup(GoogleAuthProvider());
      } else {
        await user.linkWithProvider(GoogleAuthProvider());
      }
    } on FirebaseAuthException catch (error) {
      if (_googleAuthCancelCodes.contains(error.code)) {
        return GoogleAuthResult.canceled;
      }
      if (error.code == 'credential-already-in-use' ||
          error.code == 'email-already-in-use' ||
          error.code == 'provider-already-linked') {
        return GoogleAuthResult.accountAlreadyLinked;
      }
      return GoogleAuthResult.failed;
    }

    return GoogleAuthResult.success;
  };
});

/// Signs into an existing Google-linked account, replacing the current
/// session on this device, then rebuilds the data chain on the new uid.
final signInWithGoogleProvider =
    Provider<Future<GoogleAuthResult> Function()>((ref) {
  return () async {
    final auth = ref.read(firebaseAuthProvider);
    try {
      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        await auth.signInWithProvider(GoogleAuthProvider());
      }
    } on FirebaseAuthException catch (error) {
      return _googleAuthCancelCodes.contains(error.code)
          ? GoogleAuthResult.canceled
          : GoogleAuthResult.failed;
    }

    ref.invalidate(signedInUserProvider);
    // Sync the local onboarding flag with whether this account has a
    // profile: skip onboarding for returning users, run it for new ones.
    final store = await ref.read(userFirestoreProvider.future);
    final profileSnapshot = await store.profileDoc.get();
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setBool(onboardingCompleteKey, profileSnapshot.exists);
    ref.invalidate(onboardingCompleteProvider);

    return GoogleAuthResult.success;
  };
});

/// The signed-in user's Firestore references. Also runs the one-time
/// sembast → Firestore migration before anything reads or writes.
final userFirestoreProvider = FutureProvider<UserFirestore>((ref) async {
  final user = await ref.watch(signedInUserProvider.future);
  final store = UserFirestore(ref.watch(firestoreProvider), user.uid);
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  await migrateLegacyLocalData(preferences, store);

  return store;
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
  final store = await ref.watch(userFirestoreProvider.future);
  return ProfileRepository(store);
});

final dayRepositoryProvider = FutureProvider<DayRepository>((ref) async {
  final store = await ref.watch(userFirestoreProvider.future);
  return DayRepository(store);
});

final setRepositoryProvider = FutureProvider<SetRepository>((ref) async {
  final store = await ref.watch(userFirestoreProvider.future);
  return SetRepository(store);
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

typedef DeleteSet = Future<void> Function(String setId);

final deleteSetProvider = Provider<DeleteSet>((ref) {
  return (setId) async {
    final repository = await ref.read(setRepositoryProvider.future);
    await repository.deleteSet(setId);
    ref
      ..invalidate(todayProvider)
      ..invalidate(todaySetsProvider)
      ..invalidate(allDaysProvider)
      ..invalidate(allSetsProvider);
  };
});

final exportJsonProvider = Provider<Future<String> Function()>((ref) {
  return () async {
    final store = await ref.read(userFirestoreProvider.future);
    final profileSnapshot = await store.profileDoc.get();
    final profileData = profileSnapshot.data();
    final profile = profileData == null
        ? null
        : Profile.fromMap(profileSnapshot.id, profileData);
    final days = [
      for (final document in (await store.days.orderBy('date').get()).docs)
        DayLog.fromMap(document.id, document.data()),
    ];
    final sets = [
      for (final document in (await store.sets.orderBy('loggedAt').get()).docs)
        PushupSet.fromMap(document.id, document.data()),
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
          },
      ],
      'sets': [
        for (final set in sets)
          {
            'id': set.id,
            'reps': set.reps,
            'loggedAt': set.loggedAt.toIso8601String(),
            'date': set.date,
            'note': set.note,
          },
      ],
    });
  };
});

final seedDemoDataProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final store = await ref.read(userFirestoreProvider.future);
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);

    final profileSnapshot = await store.profileDoc.get();
    final existingDates = {
      for (final document in (await store.days.get()).docs)
        document.data()['date']! as String,
    };

    final batch = store.firestore.batch();
    if (!profileSnapshot.exists) {
      final profile = Profile()
        ..name = 'Demo'
        ..currentGoal = 100
        ..themeMode = 'dark'
        ..createdAt = now;
      batch.set(store.profileDoc, profile.toMap());
    }

    for (var offset = 0; offset < 90; offset += 1) {
      final date = today.subtract(Duration(days: offset));
      final key = localDateKey(date);
      if (existingDates.contains(key)) {
        continue;
      }

      final reps = offset % 6 == 0 ? 0 : 45 + ((offset * 17) % 95);
      if (reps > 0) {
        final set = PushupSet()
          ..reps = reps
          ..loggedAt = DateTime(date.year, date.month, date.day, 12)
          ..date = key;
        batch.set(store.sets.doc(), set.toMap());
      }

      final day = DayLog()
        ..date = key
        ..goal = 100
        ..totalReps = reps
        ..completedAt = reps >= 100
            ? DateTime(date.year, date.month, date.day, 12)
            : null;
      batch.set(store.days.doc(key), day.toMap());
    }
    await batch.commit();

    ref
      ..invalidate(profileProvider)
      ..invalidate(todayProvider)
      ..invalidate(todaySetsProvider)
      ..invalidate(allDaysProvider)
      ..invalidate(allSetsProvider);
  };
});

final allDaysProvider = StreamProvider<List<DayLog>>((ref) async* {
  final store = await ref.watch(userFirestoreProvider.future);
  yield* store.days.orderBy('date').snapshots().map(
        (snapshot) => [
          for (final document in snapshot.docs)
            DayLog.fromMap(document.id, document.data()),
        ],
      );
});

final allSetsProvider = StreamProvider<List<PushupSet>>((ref) async* {
  final store = await ref.watch(userFirestoreProvider.future);
  yield* store.sets.orderBy('loggedAt').snapshots().map(
        (snapshot) => [
          for (final document in snapshot.docs)
            PushupSet.fromMap(document.id, document.data()),
        ],
      );
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository(ref.watch(firestoreProvider));
});

final leaderboardProvider = StreamProvider<List<LeaderboardEntry>>((
  ref,
) async* {
  await ref.watch(signedInUserProvider.future);
  yield* ref.watch(leaderboardRepositoryProvider).watchTop();
});

/// Publishes this user's public stats (name, totals, streak) to the shared
/// leaderboard whenever their local data changes. Watched by the Home and
/// Leaderboard screens so the entry stays fresh without any server code.
final leaderboardSyncProvider = Provider<void>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  final days = ref.watch(allDaysProvider).valueOrNull;
  final store = ref.watch(userFirestoreProvider).valueOrNull;
  if (profile == null || days == null || store == null) {
    return;
  }

  final now = ref.watch(clockProvider)();
  final todayKey = localDateKey(now);
  var totalReps = 0;
  var todayReps = 0;
  for (final day in days) {
    totalReps += day.totalReps;
    if (day.date == todayKey) {
      todayReps = day.totalReps;
    }
  }

  final entry = LeaderboardEntry()
    ..id = store.uid
    ..name = profile.name
    ..totalReps = totalReps
    ..currentStreak =
        ref.watch(streakCalculatorProvider).currentStreak(days, now)
    ..todayReps = todayReps
    ..updatedAt = now;
  final repository = ref.read(leaderboardRepositoryProvider);
  unawaited(() async {
    try {
      await repository.publish(entry);
    } on Exception {
      // Best-effort: the next data change retries.
    }
  }());
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
