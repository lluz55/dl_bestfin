import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/streaks.dart';

part 'streaks_dao.g.dart';

@DriftAccessor(tables: [Streaks])
class StreaksDao extends DatabaseAccessor<AppDatabase> with _$StreaksDaoMixin {
  StreaksDao(super.db);

  // ── Reads ──────────────────────────────────────────────────────────────────

  Stream<List<Streak>> watchAllStreaks() {
    return select(streaks).watch();
  }

  Future<Streak?> getStreakByType(String type) {
    return (select(streaks)..where((s) => s.type.equals(type))).getSingleOrNull();
  }

  Stream<Streak?> watchStreakByType(String type) {
    return (select(streaks)..where((s) => s.type.equals(type))).watchSingleOrNull();
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<int> upsertStreak(StreaksCompanion streak) {
    return into(streaks).insertOnConflictUpdate(streak);
  }

  Future<void> updateStreakCount(String id, int current, int longest, DateTime? lastDate, bool isActive) {
    return (update(streaks)..where((s) => s.id.equals(id))).write(
      StreaksCompanion(
        currentCount: Value(current),
        longestCount: Value(longest),
        lastDate: Value(lastDate),
        isActive: Value(isActive),
      ),
    );
  }
}
