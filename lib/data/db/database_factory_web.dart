import 'package:sembast_web/sembast_web.dart';

Future<Database> openPlatformDatabase(String name, String? directory) {
  // Web persists to IndexedDB; the directory hint is meaningless there.
  return databaseFactoryWeb.openDatabase(name);
}
