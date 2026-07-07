class DayLog {
  DayLog();

  factory DayLog.fromMap(int id, Map<String, Object?> map) {
    final completedAt = map['completedAt'] as String?;

    return DayLog()
      ..id = id
      ..date = map['date']! as String
      ..goal = map['goal']! as int
      ..totalReps = map['totalReps']! as int
      ..completedAt = completedAt == null ? null : DateTime.parse(completedAt)
      ..setIds = (map['setIds']! as List<Object?>).cast<int>().toList();
  }

  int id = 0;

  late String date;

  late int goal;

  late int totalReps;

  DateTime? completedAt;

  List<int> setIds = <int>[];

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'date': date,
      'goal': goal,
      'totalReps': totalReps,
      'completedAt': completedAt?.toIso8601String(),
      'setIds': setIds,
    };
  }
}
