import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

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

/// The code of the most recent Google auth failure, if any. Set whenever a
/// sign-in/link attempt throws (including redirect failures surfaced on the
/// next page load) so the UI can show it and it's not silently swallowed.
/// The app shell listens to this to raise a SnackBar — the only practical way
/// to read an error on a mobile PWA where the browser console is unreachable.
final lastAuthErrorProvider = StateProvider<String?>((ref) => null);

/// Breadcrumb describing how the last Google redirect settled (who
/// getRedirectResult returned vs who is actually signed in). The shell shows
/// it in a SnackBar when the page URL contains `authdebug` — the only way to
/// see inside the auth flow on a device with no reachable console.
final authRedirectDebugProvider = StateProvider<String?>((ref) => null);

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// The anonymous Firebase user backing this install. Signs in on first
/// launch (requires network once); afterwards the same account is restored
/// from local storage, including offline.
final signedInUserProvider = FutureProvider<User>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  // currentUser is null until the SDK finishes restoring the persisted
  // session (async on web), so wait for the first auth-state event before
  // deciding — checking currentUser too early would mint a fresh anonymous
  // account over a restored Google session.
  final existing = await auth.authStateChanges().first ?? auth.currentUser;
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
        // Popups are unreliable in mobile browsers and installed PWAs, so use
        // the redirect flow. The page unloads here; the link completes in
        // [_redirectCompletionProvider] after the browser navigates back.
        await user.linkWithRedirect(GoogleAuthProvider());
      } else {
        await user.linkWithProvider(GoogleAuthProvider());
      }
    } on FirebaseAuthException catch (error) {
      if (_googleAuthCancelCodes.contains(error.code)) {
        return GoogleAuthResult.canceled;
      }
      developer.log(
        'Google account link failed',
        name: 'push.auth',
        error: '${error.code}: ${error.message}',
      );
      ref.read(lastAuthErrorProvider.notifier).state = error.code;
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
        // Popups are unreliable in mobile browsers and installed PWAs, so use
        // the redirect flow. The page unloads here; sign-in completes in
        // [_redirectCompletionProvider] after the browser navigates back, and
        // the router routes the returning user on that fresh load. The value
        // below is effectively never returned on web.
        await auth.signInWithRedirect(GoogleAuthProvider());
        return GoogleAuthResult.success;
      }
      await auth.signInWithProvider(GoogleAuthProvider());
    } on FirebaseAuthException catch (error) {
      if (_googleAuthCancelCodes.contains(error.code)) {
        return GoogleAuthResult.canceled;
      }
      developer.log(
        'Google sign-in failed',
        name: 'push.auth',
        error: '${error.code}: ${error.message}',
      );
      ref.read(lastAuthErrorProvider.notifier).state = error.code;
      return GoogleAuthResult.failed;
    }

    ref.invalidate(signedInUserProvider);
    await _syncOnboardingCompleteFlag(ref);
    ref.invalidate(onboardingCompleteProvider);

    return GoogleAuthResult.success;
  };
});

/// Points the local onboarding flag at whether the currently signed-in account
/// has a profile: returning users skip onboarding, new ones run it. Reads
/// through the user data chain, so callers that just switched accounts must
/// invalidate [signedInUserProvider] first.
Future<void> _syncOnboardingCompleteFlag(Ref ref) async {
  final store = await ref.read(userFirestoreProvider.future);
  final profileSnapshot = await store.profileDoc.get();
  final preferences = await ref.read(sharedPreferencesProvider.future);
  await preferences.setBool(onboardingCompleteKey, profileSnapshot.exists);
}

/// Web only: settles a Google sign-in/link redirect started on the previous
/// page load. [FirebaseAuth.signInWithRedirect] navigates away, so the pending
/// operation is processed on the next load by calling
/// [FirebaseAuth.getRedirectResult] — which also updates `currentUser`. We do
/// NOT branch on its returned user: cookie-restricted browsers can report a
/// null user even after the session is restored, so the onboarding decision is
/// made from the account's Firestore profile in [onboardingCompleteProvider]
/// instead. A failed redirect surfaces its code via [lastAuthErrorProvider].
/// Resolves immediately (does nothing) on native platforms.
final _redirectCompletionProvider = FutureProvider<void>((ref) async {
  if (!kIsWeb) {
    return;
  }
  final auth = ref.watch(firebaseAuthProvider);
  String describe(User? user) {
    if (user == null) {
      return 'null';
    }
    final providers = user.providerData.map((p) => p.providerId).join('+');
    return '${user.uid.substring(0, 6)}'
        '(${user.isAnonymous ? 'anon' : providers})';
  }

  try {
    final result = await auth.getRedirectResult();
    ref.read(authRedirectDebugProvider.notifier).state =
        'redirect=${describe(result.user)} '
        'current=${describe(auth.currentUser)}';
  } on FirebaseAuthException catch (error) {
    developer.log(
      'Google redirect sign-in returned an error',
      name: 'push.auth',
      error: '${error.code}: ${error.message}',
    );
    ref.read(authRedirectDebugProvider.notifier).state =
        'redirect threw ${error.code}: ${error.message}';
    ref.read(lastAuthErrorProvider.notifier).state = error.code;
  }
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
  final localFlag = preferences.getBool(onboardingCompleteKey) ?? false;

  if (!kIsWeb) {
    return localFlag;
  }

  // Web: a returning Google user may sign in from a browser that never ran
  // onboarding locally, so the local flag alone would loop them back to setup.
  // Settle any pending redirect, then trust the account's Firestore profile as
  // the real "has this user onboarded?" signal, healing the local flag.
  await ref.watch(_redirectCompletionProvider.future);
  try {
    final store = await ref.watch(userFirestoreProvider.future);
    final profile = await store.profileDoc.get();
    if (profile.exists && !localFlag) {
      await preferences.setBool(onboardingCompleteKey, true);
    }
    return profile.exists || localFlag;
  } on Exception catch (error) {
    // Don't demote an onboarded user on a transient read failure; fall back
    // to whatever the local flag says — but surface it, because a returning
    // Google user routed by this fallback looks identical to a failed
    // sign-in.
    developer.log(
      'Onboarding profile check failed; using local flag',
      name: 'push.auth',
      error: error,
    );
    ref.read(lastAuthErrorProvider.notifier).state =
        'profile-check-failed: $error';
    return localFlag;
  }
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
