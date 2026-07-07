import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/db/entities/profile.dart';
import 'package:push_app/data/db/entities/pushup_set.dart';
import 'package:push_app/data/db/push_database.dart';
import 'package:push_app/data/repositories/date_key.dart';
import 'package:sembast/sembast.dart';

class SetRepository {
  const SetRepository(this._db);

  final Database _db;

  Future<PushupSet> addSet({
    required int reps,
    required DateTime loggedAt,
    required int dailyGoal,
    String? note,
  }) {
    if (reps <= 0) {
      throw ArgumentError.value(reps, 'reps', 'must be greater than zero');
    }

    return _db.transaction((txn) async {
      final date = localDateKey(loggedAt);
      final daySnapshot = await dayLogStore.findFirst(
        txn,
        finder: Finder(filter: Filter.equals('date', date)),
      );
      var day = daySnapshot == null
          ? null
          : DayLog.fromMap(daySnapshot.key, daySnapshot.value);
      if (day == null) {
        final profileSnapshot = await profileStore.findFirst(txn);
        final profile = profileSnapshot == null
            ? null
            : Profile.fromMap(profileSnapshot.key, profileSnapshot.value);
        day = DayLog()
          ..date = date
          ..goal = profile?.currentGoal ?? dailyGoal
          ..totalReps = 0;
      }

      final set = PushupSet()
        ..reps = reps
        ..loggedAt = loggedAt
        ..note = note;
      set.id = await pushupSetStore.add(txn, set.toMap());

      day = day
        ..totalReps += reps
        ..setIds = [...day.setIds, set.id];
      day.completedAt ??= day.totalReps >= day.goal ? loggedAt : null;
      if (daySnapshot == null) {
        day.id = await dayLogStore.add(txn, day.toMap());
      } else {
        await dayLogStore.record(day.id).put(txn, day.toMap());
      }

      return set;
    });
  }

  Future<List<PushupSet>> findSetsForDay(DayLog day) async {
    if (day.setIds.isEmpty) {
      return <PushupSet>[];
    }

    final snapshots = await pushupSetStore.records(day.setIds).getSnapshots(
          _db,
        );

    return [
      for (final snapshot in snapshots)
        if (snapshot != null) PushupSet.fromMap(snapshot.key, snapshot.value),
    ];
  }

  Future<void> deleteSet(int setId) {
    return _db.transaction((txn) async {
      final setSnapshot = await pushupSetStore.record(setId).getSnapshot(txn);
      if (setSnapshot == null) {
        return;
      }
      final set = PushupSet.fromMap(setSnapshot.key, setSnapshot.value);

      final date = localDateKey(set.loggedAt);
      final daySnapshot = await dayLogStore.findFirst(
        txn,
        finder: Finder(filter: Filter.equals('date', date)),
      );
      if (daySnapshot != null) {
        final day = DayLog.fromMap(daySnapshot.key, daySnapshot.value);
        final nextTotal = day.totalReps - set.reps;
        day
          ..totalReps = nextTotal < 0 ? 0 : nextTotal
          ..setIds = day.setIds.where((id) => id != setId).toList()
          ..completedAt = nextTotal >= day.goal ? day.completedAt : null;
        await dayLogStore.record(day.id).put(txn, day.toMap());
      }

      await pushupSetStore.record(setId).delete(txn);
    });
  }
}
