class PushupSet {
  PushupSet();

  factory PushupSet.fromMap(int id, Map<String, Object?> map) {
    return PushupSet()
      ..id = id
      ..reps = map['reps']! as int
      ..loggedAt = DateTime.parse(map['loggedAt']! as String)
      ..note = map['note'] as String?;
  }

  int id = 0;

  late int reps;

  late DateTime loggedAt;

  String? note;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'reps': reps,
      'loggedAt': loggedAt.toIso8601String(),
      'note': note,
    };
  }
}
