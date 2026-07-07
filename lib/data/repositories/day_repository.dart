import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/db/push_database.dart';
import 'package:sembast/sembast.dart';

class DayRepository {
  const DayRepository(this._db);

  final Database _db;

  Future<DayLog?> findByDate(String date) async {
    final snapshot = await dayLogStore.findFirst(
      _db,
      finder: Finder(filter: Filter.equals('date', date)),
    );

    return snapshot == null
        ? null
        : DayLog.fromMap(snapshot.key, snapshot.value);
  }

  Stream<DayLog?> watchByDate(String date) {
    return dayLogStore
        .query(finder: Finder(filter: Filter.equals('date', date)))
        .onSnapshots(_db)
        .map(
          (snapshots) => snapshots.isEmpty
              ? null
              : DayLog.fromMap(snapshots.first.key, snapshots.first.value),
        );
  }

  Future<DayLog> getOrCreate({
    required String date,
    required int goal,
  }) {
    return _db.transaction((txn) async {
      final existing = await dayLogStore.findFirst(
        txn,
        finder: Finder(filter: Filter.equals('date', date)),
      );
      if (existing != null) {
        return DayLog.fromMap(existing.key, existing.value);
      }

      final day = DayLog()
        ..date = date
        ..goal = goal
        ..totalReps = 0;
      day.id = await dayLogStore.add(txn, day.toMap());

      return day;
    });
  }

  Future<List<DayLog>> findRange({
    required String startDate,
    required String endDate,
  }) async {
    final snapshots = await dayLogStore.find(
      _db,
      finder: Finder(
        filter: Filter.and([
          Filter.greaterThanOrEquals('date', startDate),
          Filter.lessThanOrEquals('date', endDate),
        ]),
        sortOrders: [SortOrder('date')],
      ),
    );

    return [
      for (final snapshot in snapshots)
        DayLog.fromMap(snapshot.key, snapshot.value),
    ];
  }
}
