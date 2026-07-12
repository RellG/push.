import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:push_app/data/db/entities/leaderboard_entry.dart';

/// First day of the current leaderboard season, as a `localDateKey`-format
/// key: only reps on/after this date count toward the published season
/// total (`yyyy-MM-dd` keys compare correctly as strings). Bump this to
/// start a fresh race — entries republish with the new total the next time
/// each user opens the app. Users' full history is unaffected.
const leaderboardSeasonStartKey = '2026-07-12';

/// The shared `leaderboard` collection: one public-stats document per user,
/// readable by every signed-in user, writable only by its owner (enforced by
/// firestore.rules).
class LeaderboardRepository {
  const LeaderboardRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('leaderboard');

  Stream<List<LeaderboardEntry>> watchTop({int limit = 100}) {
    return _collection
        .orderBy('totalReps', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => [
            for (final document in snapshot.docs)
              LeaderboardEntry.fromMap(document.id, document.data()),
          ],
        );
  }

  Future<void> publish(LeaderboardEntry entry) {
    return _collection.doc(entry.id).set(entry.toMap());
  }
}
