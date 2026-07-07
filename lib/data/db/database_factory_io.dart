import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openPlatformDatabase(String name, String? directory) async {
  final databaseDirectory =
      directory ?? (await getApplicationDocumentsDirectory()).path;

  return databaseFactoryIo.openDatabase('$databaseDirectory/$name.db');
}
