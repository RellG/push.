import 'package:isar/isar.dart';

part 'profile.g.dart';

@collection
class Profile {
  Id id = Isar.autoIncrement;

  late String name;

  late int currentGoal;

  late String themeMode;

  late DateTime createdAt;
}
