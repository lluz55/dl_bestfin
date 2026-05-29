import '../models/streak.dart';

abstract class StreakRepository {
  Stream<List<StreakModel>> watchAllStreaks();
  Stream<StreakModel?> watchStreakByType(StreakType type);
  Future<void> updateRecordingStreak();
  Future<void> updateBudgetStreak(bool underBudget);
  Future<void> checkAndResetStreaks();
}
