import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/badges.dart';

part 'badges_dao.g.dart';

@DriftAccessor(tables: [Badges])
class BadgesDao extends DatabaseAccessor<AppDatabase> with _$BadgesDaoMixin {
  BadgesDao(super.db);

  // ── Reads ──────────────────────────────────────────────────────────────────

  Stream<List<Badge>> watchAllBadges() {
    return select(badges).watch();
  }

  Future<List<Badge>> getAllBadges() {
    return select(badges).get();
  }

  Future<Badge?> getBadgeByKey(String key) {
    return (select(badges)..where((b) => b.badgeKey.equals(key))).getSingleOrNull();
  }

  Stream<Badge?> watchBadgeByKey(String key) {
    return (select(badges)..where((b) => b.badgeKey.equals(key))).watchSingleOrNull();
  }

  Future<int> getUnlockedBadgesCount() async {
    final query = select(badges)..where((b) => b.unlockedAt.isNotNull());
    final result = await query.get();
    return result.length;
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<int> insertBadge(BadgesCompanion badge) {
    return into(badges).insertOnConflictUpdate(badge);
  }

  Future<void> unlockBadge(String key) async {
    final badge = await getBadgeByKey(key);
    if (badge != null && badge.unlockedAt == null) {
      await (update(badges)..where((b) => b.badgeKey.equals(key))).write(
        BadgesCompanion(
          unlockedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> resetAllBadges() {
    return update(badges).write(
      const BadgesCompanion(
        unlockedAt: Value.absent(),
      ),
    );
  }
}
