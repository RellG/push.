import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/data/db/entities/leaderboard_entry.dart';
import 'package:push_app/data/repositories/leaderboard_repository.dart';

void main() {
  test('publish upserts and watchTop orders by total reps', () async {
    final repository = LeaderboardRepository(FakeFirebaseFirestore());

    LeaderboardEntry entry(String id, String name, int total) {
      return LeaderboardEntry()
        ..id = id
        ..name = name
        ..totalReps = total
        ..currentStreak = 3
        ..todayReps = 20
        ..updatedAt = DateTime(2026, 7, 8, 12);
    }

    await repository.publish(entry('a', 'Rell', 500));
    await repository.publish(entry('b', 'Buddy', 900));
    await repository.publish(entry('a', 'Rell', 950));

    final board = await repository.watchTop().first;

    expect(board, hasLength(2));
    expect(board.first.id, 'a');
    expect(board.first.totalReps, 950);
    expect(board.last.name, 'Buddy');
  });
}
