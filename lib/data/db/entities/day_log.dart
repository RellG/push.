import 'package:isar/isar.dart';

part 'day_log.g.dart';

@collection
class DayLog {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String date;

  late int goal;

  late int totalReps;

  DateTime? completedAt;

  List<int> setIds = <int>[];
}
