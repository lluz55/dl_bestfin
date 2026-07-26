import 'package:bestfin/core/database/daos/streaks_dao.dart';
import 'package:bestfin/features/gamification/domain/models/streak.dart';
import 'package:bestfin/features/gamification/domain/repositories/streak_repository.dart';

class StreakRepositoryImpl implements StreakRepository {
  final StreaksDao _streaksDao;

  StreakRepositoryImpl(this._streaksDao);

  @override
  Stream<List<StreakModel>> watchAllStreaks() {
    return _streaksDao.watchAllStreaks().map(
      (list) => list.map((s) => StreakModel.fromDb(s)).toList(),
    );
  }

  @override
  Stream<StreakModel?> watchStreakByType(StreakType type) {
    return _streaksDao
        .watchStreakByType(type.value)
        .map((s) => s != null ? StreakModel.fromDb(s) : null);
  }

  @override
  Future<void> updateRecordingStreak() async {
    final streak = await _streaksDao.getStreakByType(
      StreakType.recording.value,
    );
    if (streak == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (streak.lastDate != null) {
      final lastDate = DateTime(
        streak.lastDate!.year,
        streak.lastDate!.month,
        streak.lastDate!.day,
      );

      if (lastDate.isAtSameMomentAs(today)) {
        // Already recorded today
        return;
      }

      final yesterday = today.subtract(const Duration(days: 1));
      int newCount;
      if (lastDate.isAtSameMomentAs(yesterday)) {
        newCount = streak.currentCount + 1;
      } else {
        newCount = 1;
      }

      final newLongest = newCount > streak.longestCount
          ? newCount
          : streak.longestCount;

      await _streaksDao.updateStreakCount(
        streak.id,
        newCount,
        newLongest,
        today,
        true,
      );
    } else {
      // First recording
      await _streaksDao.updateStreakCount(streak.id, 1, 1, today, true);
    }
  }

  @override
  Future<void> updateBudgetStreak(bool underBudget) async {
    final streak = await _streaksDao.getStreakByType(StreakType.budget.value);
    if (streak == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (streak.lastDate != null) {
      final lastDate = DateTime(
        streak.lastDate!.year,
        streak.lastDate!.month,
        streak.lastDate!.day,
      );

      if (lastDate.isAtSameMomentAs(today)) {
        if (!underBudget && streak.currentCount > 0) {
          // Exceeded budget today, reset
          await _streaksDao.updateStreakCount(
            streak.id,
            0,
            streak.longestCount,
            today,
            false,
          );
        }
        return;
      }
    }

    if (underBudget) {
      final yesterday = today.subtract(const Duration(days: 1));
      int newCount;

      if (streak.lastDate != null &&
          DateTime(
            streak.lastDate!.year,
            streak.lastDate!.month,
            streak.lastDate!.day,
          ).isAtSameMomentAs(yesterday)) {
        newCount = streak.currentCount + 1;
      } else {
        newCount = 1;
      }

      final newLongest = newCount > streak.longestCount
          ? newCount
          : streak.longestCount;

      await _streaksDao.updateStreakCount(
        streak.id,
        newCount,
        newLongest,
        today,
        true,
      );
    } else {
      await _streaksDao.updateStreakCount(
        streak.id,
        0,
        streak.longestCount,
        today,
        false,
      );
    }
  }

  @override
  Future<void> checkAndResetStreaks() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final streaks = await _streaksDao.select(_streaksDao.streaks).get();

    for (final streak in streaks) {
      if (streak.lastDate == null) continue;

      final lastDate = DateTime(
        streak.lastDate!.year,
        streak.lastDate!.month,
        streak.lastDate!.day,
      );

      if (lastDate.isBefore(yesterday)) {
        // Streak broken
        await _streaksDao.updateStreakCount(
          streak.id,
          0,
          streak.longestCount,
          streak.lastDate,
          false,
        );
      }
    }
  }
}
