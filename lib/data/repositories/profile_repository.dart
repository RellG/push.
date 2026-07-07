import 'package:push_app/data/db/entities/profile.dart';
import 'package:push_app/data/db/push_database.dart';
import 'package:sembast/sembast.dart';

class ProfileRepository {
  const ProfileRepository(this._db);

  final Database _db;

  Future<Profile?> getProfile() => _getProfile(_db);

  Future<Profile?> _getProfile(DatabaseClient client) async {
    final snapshot = await profileStore.findFirst(client);

    return snapshot == null
        ? null
        : Profile.fromMap(snapshot.key, snapshot.value);
  }

  Stream<Profile?> watchProfile() {
    return profileStore.query().onSnapshots(_db).map(
          (snapshots) => snapshots.isEmpty
              ? null
              : Profile.fromMap(snapshots.first.key, snapshots.first.value),
        );
  }

  Future<Profile> saveProfile({
    required String name,
    required int currentGoal,
    required String themeMode,
    DateTime? createdAt,
  }) {
    return _db.transaction((txn) async {
      final existing = await _getProfile(txn);
      final profile = (existing ?? Profile())
        ..name = name
        ..currentGoal = currentGoal
        ..themeMode = themeMode
        ..createdAt = existing?.createdAt ?? createdAt ?? DateTime.now();

      if (existing == null) {
        profile.id = await profileStore.add(txn, profile.toMap());
      } else {
        await profileStore.record(profile.id).put(txn, profile.toMap());
      }

      return profile;
    });
  }

  Future<void> updateGoal(int goal) {
    return _db.transaction((txn) async {
      final profile = await _getProfile(txn);
      if (profile == null) {
        return;
      }

      profile.currentGoal = goal;
      await profileStore.record(profile.id).put(txn, profile.toMap());
    });
  }

  Future<void> updateThemeMode(String themeMode) {
    return _db.transaction((txn) async {
      final profile = await _getProfile(txn);
      if (profile == null) {
        return;
      }

      profile.themeMode = themeMode;
      await profileStore.record(profile.id).put(txn, profile.toMap());
    });
  }
}
