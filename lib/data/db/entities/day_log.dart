class DayLog {
  DayLog();

  factory DayLog.fromMap(String id, Map<String, Object?> map) {
    final completedAt = map['completedAt'] as String?;

    return DayLog()
      ..id = id
      ..date = map['date']! as String
      ..goal = map['goal']! as int
      ..totalReps = map['totalReps']! as int
      ..completedAt = completedAt == null ? null : DateTime.parse(completedAt);
  }

  /// Firestore document id — the same `yyyy-MM-dd` key as [date].
  String id = '';

  late String date;

  late int goal;

  late int totalReps;

  DateTime? completedAt;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'date': date,
      'goal': goal,
      'totalReps': totalReps,
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
