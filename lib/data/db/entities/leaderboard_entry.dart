class LeaderboardEntry {
  LeaderboardEntry();

  factory LeaderboardEntry.fromMap(String id, Map<String, Object?> map) {
    return LeaderboardEntry()
      ..id = id
      ..name = map['name']! as String
      ..totalReps = map['totalReps']! as int
      ..currentStreak = map['currentStreak']! as int
      ..todayReps = map['todayReps']! as int
      ..updatedAt = DateTime.parse(map['updatedAt']! as String);
  }

  /// Firestore document id — the owning user's uid.
  String id = '';

  late String name;

  late int totalReps;

  late int currentStreak;

  late int todayReps;

  late DateTime updatedAt;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': name,
      'totalReps': totalReps,
      'currentStreak': currentStreak,
      'todayReps': todayReps,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
