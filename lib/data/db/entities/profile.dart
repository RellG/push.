class Profile {
  Profile();

  factory Profile.fromMap(String id, Map<String, Object?> map) {
    return Profile()
      ..id = id
      ..name = map['name']! as String
      ..currentGoal = map['currentGoal']! as int
      ..themeMode = map['themeMode']! as String
      ..createdAt = DateTime.parse(map['createdAt']! as String);
  }

  /// Firestore document id — the owning user's uid.
  String id = '';

  late String name;

  late int currentGoal;

  late String themeMode;

  late DateTime createdAt;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': name,
      'currentGoal': currentGoal,
      'themeMode': themeMode,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
