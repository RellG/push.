import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/db/entities/profile.dart';
import 'package:push_app/data/db/entities/pushup_set.dart';
import 'package:push_app/data/firestore/user_firestore.dart';
import 'package:push_app/data/repositories/date_key.dart';

class SetRepository {
  const SetRepository(this._store);

  final UserFirestore _store;

  Future<PushupSet> addSet({
    required int reps,
    required DateTime loggedAt,
    required int dailyGoal,
    String? note,
  }) {
    if (reps <= 0) {
      throw ArgumentError.value(reps, 'reps', 'must be greater than zero');
    }

    final date = localDateKey(loggedAt);
    final dayReference = _store.days.doc(date);
    final setReference = _store.sets.doc();

    return _store.firestore.runTransaction((txn) async {
      // Firestore transactions require every read before the first write.
      final daySnapshot = await txn.get(dayReference);
      final dayData = daySnapshot.data();
      var day =
          dayData == null ? null : DayLog.fromMap(daySnapshot.id, dayData);
      if (day == null) {
        final profileSnapshot = await txn.get(_store.profileDoc);
        final profileData = profileSnapshot.data();
        final profile = profileData == null
            ? null
            : Profile.fromMap(profileSnapshot.id, profileData);
        day = DayLog()
          ..id = date
          ..date = date
          ..goal = profile?.currentGoal ?? dailyGoal
          ..totalReps = 0;
      }

      final set = PushupSet()
        ..id = setReference.id
        ..reps = reps
        ..loggedAt = loggedAt
        ..date = date
        ..note = note;
      txn.set(setReference, set.toMap());

      final total = day.totalReps + reps;
      day
        ..totalReps = total
        ..completedAt ??= total >= day.goal ? loggedAt : null;
      txn.set(dayReference, day.toMap());

      return set;
    });
  }

  Future<List<PushupSet>> findSetsForDay(DayLog day) async {
    final snapshot = await _store.sets
        .where('date', isEqualTo: day.date)
        .orderBy('loggedAt')
        .get();

    return [
      for (final document in snapshot.docs)
        PushupSet.fromMap(document.id, document.data()),
    ];
  }

  Future<void> deleteSet(String setId) {
    final setReference = _store.sets.doc(setId);

    return _store.firestore.runTransaction((txn) async {
      final setSnapshot = await txn.get(setReference);
      final setData = setSnapshot.data();
      if (setData == null) {
        return;
      }
      final set = PushupSet.fromMap(setSnapshot.id, setData);

      final dayReference = _store.days.doc(set.date);
      final daySnapshot = await txn.get(dayReference);
      final dayData = daySnapshot.data();
      if (dayData != null) {
        final day = DayLog.fromMap(daySnapshot.id, dayData);
        final nextTotal = day.totalReps - set.reps;
        day
          ..totalReps = nextTotal < 0 ? 0 : nextTotal
          ..completedAt = nextTotal >= day.goal ? day.completedAt : null;
        txn.set(dayReference, day.toMap());
      }

      txn.delete(setReference);
    });
  }
}
