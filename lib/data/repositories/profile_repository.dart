import 'package:isar/isar.dart';
import 'package:push_app/data/db/entities/profile.dart';

class ProfileRepository {
  const ProfileRepository(this._isar);

  final Isar _isar;

  Future<Profile?> getProfile() {
    return _isar.profiles.where().findFirst();
  }

  Stream<Profile?> watchProfile() {
    return _isar.profiles
        .where()
        .watch(fireImmediately: true)
        .map((profiles) => profiles.firstOrNull);
  }

  Future<Profile> saveProfile({
    required String name,
    required int currentGoal,
    required String themeMode,
    DateTime? createdAt,
  }) {
    return _isar.writeTxn(() async {
      final existing = await getProfile();
      final profile = existing ?? Profile();
      profile
        ..name = name
        ..currentGoal = currentGoal
        ..themeMode = themeMode
        ..createdAt = existing?.createdAt ?? createdAt ?? DateTime.now();
      profile.id = await _isar.profiles.put(profile);

      return profile;
    });
  }

  Future<void> updateGoal(int goal) {
    return _isar.writeTxn(() async {
      final profile = await getProfile();
      if (profile == null) {
        return;
      }

      profile.currentGoal = goal;
      await _isar.profiles.put(profile);
    });
  }

  Future<void> updateThemeMode(String themeMode) {
    return _isar.writeTxn(() async {
      final profile = await getProfile();
      if (profile == null) {
        return;
      }

      profile.themeMode = themeMode;
      await _isar.profiles.put(profile);
    });
  }
}
