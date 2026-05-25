import 'package:isar/isar.dart';

part 'pushup_set.g.dart';

@collection
class PushupSet {
  Id id = Isar.autoIncrement;

  late int reps;

  late DateTime loggedAt;

  String? note;
}
