import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/firestore/user_firestore.dart';

class DayRepository {
  const DayRepository(this._store);

  final UserFirestore _store;

  Future<DayLog?> findByDate(String date) async {
    final snapshot = await _store.days.doc(date).get();
    final data = snapshot.data();

    return data == null ? null : DayLog.fromMap(snapshot.id, data);
  }

  Stream<DayLog?> watchByDate(String date) {
    return _store.days.doc(date).snapshots().map((snapshot) {
      final data = snapshot.data();

      return data == null ? null : DayLog.fromMap(snapshot.id, data);
    });
  }

  Future<DayLog> getOrCreate({
    required String date,
    required int goal,
  }) {
    final reference = _store.days.doc(date);

    return _store.firestore.runTransaction((txn) async {
      final snapshot = await txn.get(reference);
      final data = snapshot.data();
      if (data != null) {
        return DayLog.fromMap(snapshot.id, data);
      }

      final day = DayLog()
        ..id = date
        ..date = date
        ..goal = goal
        ..totalReps = 0;
      txn.set(reference, day.toMap());

      return day;
    });
  }

  Future<List<DayLog>> findRange({
    required String startDate,
    required String endDate,
  }) async {
    final snapshot = await _store.days
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .orderBy('date')
        .get();

    return [
      for (final document in snapshot.docs)
        DayLog.fromMap(document.id, document.data()),
    ];
  }
}
