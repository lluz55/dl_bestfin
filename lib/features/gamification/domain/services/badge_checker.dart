import 'dart:async';
import '../../../transactions/data/repositories/transaction_repository.dart';
import '../../../goals/data/repositories/goal_repository.dart';
import '../../../investments/data/repositories/investment_repository.dart';
import '../../../financing/data/repositories/financing_repository.dart';
import '../repositories/streak_repository.dart';
import '../../../../core/database/daos/badges_dao.dart';
import '../models/streak.dart';

class BadgeChecker {
  final BadgesDao _badgesDao;
  final TransactionRepository _transactionRepository;
  final GoalRepository _goalRepository;
  final InvestmentRepository _investmentRepository;
  final FinancingRepository _financingRepository;
  final StreakRepository _streakRepository;

  final _badgeUnlockController = StreamController<String>.broadcast();
  Stream<String> get onBadgeUnlocked => _badgeUnlockController.stream;

  BadgeChecker({
    required BadgesDao badgesDao,
    required TransactionRepository transactionRepository,
    required GoalRepository goalRepository,
    required InvestmentRepository investmentRepository,
    required FinancingRepository financingRepository,
    required StreakRepository streakRepository,
  }) : _badgesDao = badgesDao,
       _transactionRepository = transactionRepository,
       _goalRepository = goalRepository,
       _investmentRepository = investmentRepository,
       _financingRepository = financingRepository,
       _streakRepository = streakRepository;

  Future<void> checkAllBadges() async {
    await Future.wait([
      _checkFirstTransaction(),
      _checkSevenDaysStreak(),
      _checkEmergencyFund(),
      _checkDebtFree(),
      _checkGoalReached(),
      _checkFinanceMaster(),
      _checkInvestor(),
      _checkInstallmentCompleted(),
    ]);
  }

  Future<void> _unlockBadge(String key) async {
    final badge = await _badgesDao.getBadgeByKey(key);
    if (badge != null && badge.unlockedAt == null) {
      await _badgesDao.unlockBadge(key);
      _badgeUnlockController.add(key);
    }
  }

  Future<void> _checkFirstTransaction() async {
    final txs = await _transactionRepository.watchAllTransactions().first;
    if (txs.isNotEmpty) {
      await _unlockBadge('first_transaction');
    }
  }

  Future<void> _checkSevenDaysStreak() async {
    final streak = await _streakRepository
        .watchStreakByType(StreakType.recording)
        .first;
    if (streak != null && streak.currentCount >= 7) {
      await _unlockBadge('seven_days_streak');
    }
  }

  Future<void> _checkEmergencyFund() async {
    final goals = await _goalRepository.watchAllGoals().first;
    final hasEmergency = goals.any(
      (g) => g.name.toLowerCase().contains('emergência'),
    );
    if (hasEmergency) {
      await _unlockBadge('emergency_fund');
    }
  }

  Future<void> _checkDebtFree() async {
    final financings = await _financingRepository.watchAllFinancings().first;
    if (financings.isEmpty) {
      final txs = await _transactionRepository.watchAllTransactions().first;
      if (txs.isNotEmpty) {
        await _unlockBadge('debt_free');
      }
    }
  }

  Future<void> _checkGoalReached() async {
    final goals = await _goalRepository.watchAllGoals().first;
    final hasReached = goals.any(
      (g) => g.currentAmountInCents >= g.targetAmountInCents,
    );
    if (hasReached) {
      await _unlockBadge('goal_reached');
    }
  }

  Future<void> _checkFinanceMaster() async {
    final streak = await _streakRepository
        .watchStreakByType(StreakType.budget)
        .first;
    if (streak != null && streak.currentCount >= 30) {
      await _unlockBadge('finance_master');
    }
  }

  Future<void> _checkInvestor() async {
    final investments = await _investmentRepository.watchAllInvestments().first;
    if (investments.isNotEmpty) {
      await _unlockBadge('investor');
    }
  }

  Future<void> _checkInstallmentCompleted() async {
    // This one is trickier as it depends on how installments are marked as completed.
    // For now, let's check if there are any completed financings or installment plans.
    // Based on the database, we could check if there are no pending installments for a plan.
    // Let's skip for a moment or implement a simple check.
  }

  void dispose() {
    _badgeUnlockController.close();
  }
}
