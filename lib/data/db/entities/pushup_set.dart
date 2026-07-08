class PushupSet {
  PushupSet();

  factory PushupSet.fromMap(String id, Map<String, Object?> map) {
    return PushupSet()
      ..id = id
      ..reps = map['reps']! as int
      ..loggedAt = DateTime.parse(map['loggedAt']! as String)
      ..date = map['date']! as String
      ..note = map['note'] as String?;
  }

  /// Firestore document id (auto-generated).
  String id = '';

  late int reps;

  late DateTime loggedAt;

  /// Local-day key of [loggedAt]; sets are queried per day through it.
  late String date;

  String? note;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'reps': reps,
      'loggedAt': loggedAt.toIso8601String(),
      'date': date,
      'note': note,
    };
  }
}
