import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:push_app/data/db/push_database.dart';
import 'package:push_app/data/repositories/day_repository.dart';
import 'package:push_app/data/repositories/profile_repository.dart';
import 'package:push_app/data/repositories/set_repository.dart';

void main() {
  late Directory directory;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('push_isar_test_');
    isar = await Isar.open(
      pushSchemas,
      directory: directory.path,
      name: 'test_${DateTime.now().microsecondsSinceEpoch}',
      inspector: false,
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  test('profile repository saves and updates the single profile', () async {
    final repository = ProfileRepository(isar);
    final createdAt = DateTime(2026, 5, 25, 9);

    final profile = await repository.saveProfile(
      name: 'Rell',
      currentGoal: 100,
      themeMode: 'dark',
      createdAt: createdAt,
    );
    await repository.updateGoal(120);
    await repository.updateThemeMode('system');

    final saved = await repository.getProfile();

    expect(saved, isNotNull);
    expect(saved!.id, profile.id);
    expect(saved.name, 'Rell');
    expect(saved.currentGoal, 120);
    expect(saved.themeMode, 'system');
    expect(saved.createdAt, createdAt);
  });

  test(
    'set repository creates a day log and keeps the day goal immutable',
    () async {
      final setRepository = SetRepository(isar);
      final dayRepository = DayRepository(isar);
      final loggedAt = DateTime(2026, 5, 25, 7, 30);

      final firstSet = await setRepository.addSet(
        reps: 25,
        loggedAt: loggedAt,
        dailyGoal: 100,
      );
      await setRepository.addSet(
        reps: 10,
        loggedAt: loggedAt.add(const Duration(hours: 1)),
        dailyGoal: 200,
        note: 'Clean reps',
      );

      final day = await dayRepository.findByDate('2026-05-25');
      final sets = await setRepository.findSetsForDay(day!);

      expect(day.goal, 100);
      expect(day.totalReps, 35);
      expect(day.setIds, hasLength(2));
      expect(sets.map((set) => set.reps), [25, 10]);
      expect(sets.first.id, firstSet.id);
    },
  );

  test('deleting a set removes it from the day total and set list', () async {
    final setRepository = SetRepository(isar);
    final dayRepository = DayRepository(isar);
    final loggedAt = DateTime(2026, 5, 25, 7, 30);

    final set = await setRepository.addSet(
      reps: 100,
      loggedAt: loggedAt,
      dailyGoal: 100,
    );
    await setRepository.deleteSet(set.id);

    final day = await dayRepository.findByDate('2026-05-25');
    final sets = await setRepository.findSetsForDay(day!);

    expect(day.totalReps, 0);
    expect(day.completedAt, isNull);
    expect(day.setIds, isEmpty);
    expect(sets, isEmpty);
  });
}
