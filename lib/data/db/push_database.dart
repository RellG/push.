import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:push_app/data/db/entities/day_log.dart';
import 'package:push_app/data/db/entities/profile.dart';
import 'package:push_app/data/db/entities/pushup_set.dart';

const pushSchemas = <CollectionSchema<dynamic>>[
  PushupSetSchema,
  DayLogSchema,
  ProfileSchema,
];

Future<Isar> openPushDatabase({
  String name = Isar.defaultName,
  String? directory,
}) async {
  final existing = Isar.getInstance(name);
  if (existing != null) {
    return existing;
  }

  final databaseDirectory =
      directory ?? (await getApplicationDocumentsDirectory()).path;

  return Isar.open(
    pushSchemas,
    directory: databaseDirectory,
    name: name,
    inspector: false,
  );
}
