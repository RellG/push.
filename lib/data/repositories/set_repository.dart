import 'package:isar/isar.dart';
import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/db/entities/pushup_set.dart';
import 'package:push_app/data/repositories/date_key.dart';

class SetRepository {
  const SetRepository(this._isar);

  final Isar _isar;

  Future<PushupSet> addSet({
    required int reps,
    required DateTime loggedAt,
    required int dailyGoal,
    String? note,
  }) {
    if (reps <= 0) {
      throw ArgumentError.value(reps, 'reps', 'must be greater than zero');
    }

    return _isar.writeTxn(() async {
      final date = localDateKey(loggedAt);
      var day = await _isar.dayLogs.where().dateEqualTo(date).findFirst();
      day ??= DayLog()
        ..date = date
        ..goal = dailyGoal
        ..totalReps = 0;

      final set = PushupSet()
        ..reps = reps
        ..loggedAt = loggedAt
        ..note = note;
      set.id = await _isar.pushupSets.put(set);

      day = day
        ..totalReps += reps
        ..setIds = [...day.setIds, set.id];
      day.completedAt ??= day.totalReps >= day.goal ? loggedAt : null;
      day.id = await _isar.dayLogs.put(day);

      return set;
    });
  }

  Future<List<PushupSet>> findSetsForDay(DayLog day) {
    if (day.setIds.isEmpty) {
      return Future.value(<PushupSet>[]);
    }

    return _isar.pushupSets
        .getAll(day.setIds)
        .then((sets) => sets.nonNulls.toList());
  }

  Future<void> deleteSet(int setId) {
    return _isar.writeTxn(() async {
      final set = await _isar.pushupSets.get(setId);
      if (set == null) {
        return;
      }

      final date = localDateKey(set.loggedAt);
      final day = await _isar.dayLogs.where().dateEqualTo(date).findFirst();
      if (day != null) {
        final nextTotal = day.totalReps - set.reps;
        day
          ..totalReps = nextTotal < 0 ? 0 : nextTotal
          ..setIds = day.setIds.where((id) => id != setId).toList()
          ..completedAt = nextTotal >= day.goal ? day.completedAt : null;
        await _isar.dayLogs.put(day);
      }

      await _isar.pushupSets.delete(setId);
    });
  }
}
