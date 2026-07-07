import 'package:push_app/data/db/database_factory_io.dart'
    if (dart.library.js_interop) 'package:push_app/data/db/database_factory_web.dart';
import 'package:sembast/sembast.dart';

const defaultDatabaseName = 'push';

final StoreRef<int, Map<String, Object?>> dayLogStore =
    intMapStoreFactory.store('dayLogs');
final StoreRef<int, Map<String, Object?>> profileStore =
    intMapStoreFactory.store('profiles');
final StoreRef<int, Map<String, Object?>> pushupSetStore =
    intMapStoreFactory.store('pushupSets');

final Map<String, Future<Database>> _instances = <String, Future<Database>>{};

Future<Database> openPushDatabase({
  String name = defaultDatabaseName,
  String? directory,
}) {
  return _instances.putIfAbsent(
    name,
    () => openPlatformDatabase(name, directory),
  );
}
