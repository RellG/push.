import 'package:flutter/foundation.dart';
import 'package:push_app/data/db/push_database.dart';
import 'package:push_app/data/firestore/user_firestore.dart';
import 'package:push_app/data/repositories/date_key.dart';
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';

const legacyMigrationKey = 'sembast_migrated_to_firestore';

/// Copies data written by the pre-Firebase sembast builds into the signed-in
/// user's Firestore documents, once per install.
///
/// Skipped when the user already has a Firestore profile, so it can never
/// clobber server data. Uses a single batch, which caps at 500 documents —
/// plenty for data logged by a solo pre-release tester.
Future<void> migrateLegacyLocalData(
  SharedPreferences preferences,
  UserFirestore store,
) async {
  if (preferences.getBool(legacyMigrationKey) ?? false) {
    return;
  }

  try {
    final database = await openPushDatabase();
    final profileSnapshot = await profileStore.findFirst(database);
    if (profileSnapshot != null) {
      final remoteProfile = await store.profileDoc.get();
      if (!remoteProfile.exists) {
        final daySnapshots = await dayLogStore.find(database);
        final setSnapshots = await pushupSetStore.find(database);

        final batch = store.firestore.batch()
          ..set(store.profileDoc, <String, Object?>{
            'name': profileSnapshot.value['name'],
            'currentGoal': profileSnapshot.value['currentGoal'],
            'themeMode': profileSnapshot.value['themeMode'],
            'createdAt': profileSnapshot.value['createdAt'],
          });
        for (final snapshot in daySnapshots) {
          final date = snapshot.value['date']! as String;
          batch.set(store.days.doc(date), <String, Object?>{
            'date': date,
            'goal': snapshot.value['goal'],
            'totalReps': snapshot.value['totalReps'],
            'completedAt': snapshot.value['completedAt'],
          });
        }
        for (final snapshot in setSnapshots) {
          final loggedAt = snapshot.value['loggedAt']! as String;
          batch.set(store.sets.doc(), <String, Object?>{
            'reps': snapshot.value['reps'],
            'loggedAt': loggedAt,
            'date': localDateKey(DateTime.parse(loggedAt)),
            'note': snapshot.value['note'],
          });
        }
        await batch.commit();
      }
    }
    await preferences.setBool(legacyMigrationKey, true);
  } on Exception catch (error) {
    // Leave the flag unset so the next launch retries.
    debugPrint('Push. legacy data migration failed: $error');
  }
}
