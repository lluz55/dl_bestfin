import 'package:bestfin/features/gamification/domain/repositories/streak_repository.dart';
import 'package:bestfin/features/gamification/domain/services/badge_checker.dart';

class GamificationService {
  final StreakRepository _streakRepository;
  final BadgeChecker _badgeChecker;

  GamificationService({
    required StreakRepository streakRepository,
    required BadgeChecker badgeChecker,
  }) : _streakRepository = streakRepository,
       _badgeChecker = badgeChecker;

  Stream<String> get onBadgeUnlocked => _badgeChecker.onBadgeUnlocked;

  Future<void> onTransactionCreated() async {
    await _streakRepository.updateRecordingStreak();
    await _badgeChecker.checkAllBadges();
  }

  Future<void> onGoalUpdated() async {
    await _badgeChecker.checkAllBadges();
  }

  Future<void> onFinancingUpdated() async {
    await _badgeChecker.checkAllBadges();
  }

  Future<void> onInvestmentUpdated() async {
    await _badgeChecker.checkAllBadges();
  }

  Future<void> onAppStarted() async {
    await _streakRepository.checkAndResetStreaks();
    await _badgeChecker.checkAllBadges();
  }
}
