import 'package:push_app/data/db/entities/profile.dart';
import 'package:push_app/data/firestore/user_firestore.dart';

class ProfileRepository {
  const ProfileRepository(this._store);

  final UserFirestore _store;

  Future<Profile?> getProfile() async {
    final snapshot = await _store.profileDoc.get();
    final data = snapshot.data();

    return data == null ? null : Profile.fromMap(snapshot.id, data);
  }

  Stream<Profile?> watchProfile() {
    return _store.profileDoc.snapshots().map((snapshot) {
      final data = snapshot.data();

      return data == null ? null : Profile.fromMap(snapshot.id, data);
    });
  }

  Future<Profile> saveProfile({
    required String name,
    required int currentGoal,
    required String themeMode,
    DateTime? createdAt,
  }) {
    return _store.firestore.runTransaction((txn) async {
      final snapshot = await txn.get(_store.profileDoc);
      final data = snapshot.data();
      final existing =
          data == null ? null : Profile.fromMap(snapshot.id, data);
      final profile = (existing ?? Profile())
        ..id = _store.uid
        ..name = name
        ..currentGoal = currentGoal
        ..themeMode = themeMode
        ..createdAt = existing?.createdAt ?? createdAt ?? DateTime.now();
      txn.set(_store.profileDoc, profile.toMap());

      return profile;
    });
  }

  Future<void> updateName(String name) {
    return _store.firestore.runTransaction((txn) async {
      final snapshot = await txn.get(_store.profileDoc);
      if (!snapshot.exists) {
        return;
      }

      txn.update(_store.profileDoc, <String, Object?>{'name': name});
    });
  }

  Future<void> updateGoal(int goal) {
    return _store.firestore.runTransaction((txn) async {
      final snapshot = await txn.get(_store.profileDoc);
      if (!snapshot.exists) {
        return;
      }

      txn.update(_store.profileDoc, <String, Object?>{'currentGoal': goal});
    });
  }

  Future<void> updateThemeMode(String themeMode) {
    return _store.firestore.runTransaction((txn) async {
      final snapshot = await txn.get(_store.profileDoc);
      if (!snapshot.exists) {
        return;
      }

      txn.update(_store.profileDoc, <String, Object?>{
        'themeMode': themeMode,
      });
    });
  }
}
