import 'package:isar/isar.dart';
import 'package:push_app/data/db/entities/day_log.dart';

class DayRepository {
  const DayRepository(this._isar);

  final Isar _isar;

  Future<DayLog?> findByDate(String date) {
    return _isar.dayLogs.getByDate(date);
  }

  Stream<DayLog?> watchByDate(String date) {
    return _isar.dayLogs
        .filter()
        .dateEqualTo(date)
        .watch(fireImmediately: true)
        .map((logs) => logs.firstOrNull);
  }

  Future<DayLog> getOrCreate({
    required String date,
    required int goal,
  }) async {
    final existing = await findByDate(date);
    if (existing != null) {
      return existing;
    }

    return _isar.writeTxn(() async {
      final day = DayLog()
        ..date = date
        ..goal = goal
        ..totalReps = 0;
      day.id = await _isar.dayLogs.put(day);

      return day;
    });
  }

  Future<List<DayLog>> findRange({
    required String startDate,
    required String endDate,
  }) {
    return _isar.dayLogs
        .filter()
        .dateBetween(startDate, endDate)
        .sortByDate()
        .findAll();
  }
}
