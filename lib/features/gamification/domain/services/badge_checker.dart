import 'dart:async';
import '../../../transactions/data/repositories/transaction_repository.dart';
import '../../../goals/data/repositories/goal_repository.dart';
import '../../../investments/data/repositories/investment_repository.dart';
import '../../../financing/data/repositories/financing_repository.dart';
import '../../../accounts/data/repositories/account_repository.dart';
import '../../../categories/data/repositories/category_repository.dart';
import '../../../credit_cards/data/repositories/credit_card_repository.dart';
import '../../../../core/constants/transaction_types.dart';
import '../repositories/streak_repository.dart';
import '../../../../core/database/daos/badges_dao.dart';
import '../models/streak.dart';

class BadgeChecker {
  final BadgesDao _badgesDao;
  final TransactionRepository _transactionRepository;
  final GoalRepository _goalRepository;
  final InvestmentRepository _investmentRepository;
  final FinancingRepository _financingRepository;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final CreditCardRepository _creditCardRepository;
  final StreakRepository _streakRepository;

  final _badgeUnlockController = StreamController<String>.broadcast();
  Stream<String> get onBadgeUnlocked => _badgeUnlockController.stream;

  BadgeChecker({
    required BadgesDao badgesDao,
    required TransactionRepository transactionRepository,
    required GoalRepository goalRepository,
    required InvestmentRepository investmentRepository,
    required FinancingRepository financingRepository,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required CreditCardRepository creditCardRepository,
    required StreakRepository streakRepository,
  }) : _badgesDao = badgesDao,
       _transactionRepository = transactionRepository,
       _goalRepository = goalRepository,
       _investmentRepository = investmentRepository,
       _financingRepository = financingRepository,
       _accountRepository = accountRepository,
       _categoryRepository = categoryRepository,
       _creditCardRepository = creditCardRepository,
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
      _checkFirstAccount(),
      _checkCategoryExplorer(),
      _checkMonthSaver(),
      _checkConsistencyKing(),
      _checkBudgetStreak7(),
      _checkDiversifiedPortfolio(),
      _checkCreditCardDiscipline(),
      // Médio prazo
      _checkHundredTransactions(),
      _checkThreeMonthsStreak(),
      _checkTenGoalsReached(),
      _checkBudgetMaster90(),
      _checkSavingsMilestone(),
      // Longo prazo
      _checkYearStreak(),
      _checkAllGoalsCompleted(),
      _checkInvestmentGains(),
      _checkFinancialFreedom(),
      _checkConsistentSaver(),
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
    // Só precisamos saber se existe ao menos uma transação — evita carregar e
    // mapear todo o histórico (com joins de categoria/entidade/entries).
    if (await _transactionRepository.hasAnyTransactions()) {
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
      if (await _transactionRepository.hasAnyTransactions()) {
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

  Future<void> _checkFirstAccount() async {
    final accounts = await _accountRepository.watchAllAccounts().first;
    if (accounts.isNotEmpty) {
      await _unlockBadge('first_account');
    }
  }

  Future<void> _checkCategoryExplorer() async {
    final categories = await _categoryRepository.watchCategoriesTree().first;
    // Conta apenas categorias raiz (não filhas) que são personalizadas (não-sistema)
    final customCount = categories.where((c) => !c.isSystem).length;
    if (customCount >= 5) {
      await _unlockBadge('category_explorer');
    }
  }

  Future<void> _checkMonthSaver() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final transactions = await _transactionRepository
        .watchTransactionsWithFilters(
          startDate: startOfMonth,
          endDate: endOfMonth,
          isCompleted: true,
        )
        .first;

    int totalIncome = 0;
    int totalExpense = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
      }
    }

    if (totalIncome > totalExpense && totalIncome > 0) {
      await _unlockBadge('month_saver');
    }
  }

  Future<void> _checkConsistencyKing() async {
    final streak = await _streakRepository
        .watchStreakByType(StreakType.recording)
        .first;
    if (streak != null && streak.currentCount >= 30) {
      await _unlockBadge('consistency_king');
    }
  }

  Future<void> _checkBudgetStreak7() async {
    final streak = await _streakRepository
        .watchStreakByType(StreakType.budget)
        .first;
    if (streak != null && streak.currentCount >= 7) {
      await _unlockBadge('budget_streak_7');
    }
  }

  Future<void> _checkDiversifiedPortfolio() async {
    final investments = await _investmentRepository.watchAllInvestments().first;
    final uniqueTypes = investments.map((i) => i.type).toSet();
    if (uniqueTypes.length >= 3) {
      await _unlockBadge('diversified_portfolio');
    }
  }

  Future<void> _checkCreditCardDiscipline() async {
    final cards = await _creditCardRepository.watchAllCreditCards().first;
    if (cards.isEmpty) return;
    // Desbloqueia se tem cartão e nenhum tem saldo usado (fatura paga)
    final hasDebt = cards.any((c) => c.usedLimit > 0);
    if (!hasDebt) {
      await _unlockBadge('credit_card_discipline');
    }
  }

  // ── Médio prazo (3-6 meses) ──────────────────────────────────────────────

  Future<void> _checkHundredTransactions() async {
    final transactions = await _transactionRepository
        .watchAllTransactions()
        .first;
    if (transactions.length >= 100) {
      await _unlockBadge('hundred_transactions');
    }
  }

  Future<void> _checkThreeMonthsStreak() async {
    final streak = await _streakRepository
        .watchStreakByType(StreakType.recording)
        .first;
    if (streak != null && streak.currentCount >= 90) {
      await _unlockBadge('three_months_streak');
    }
  }

  Future<void> _checkTenGoalsReached() async {
    final goals = await _goalRepository.watchAllGoals().first;
    final completedCount = goals.where(
      (g) => g.currentAmountInCents >= g.targetAmountInCents,
    ).length;
    if (completedCount >= 10) {
      await _unlockBadge('ten_goals_reached');
    }
  }

  Future<void> _checkBudgetMaster90() async {
    final streak = await _streakRepository
        .watchStreakByType(StreakType.budget)
        .first;
    if (streak != null && streak.currentCount >= 90) {
      await _unlockBadge('budget_master_90');
    }
  }

  Future<void> _checkSavingsMilestone() async {
    final goals = await _goalRepository.watchAllGoals().first;
    int totalContributions = 0;
    for (final g in goals) {
      totalContributions += g.currentAmountInCents;
    }
    // R$ 10.000 = 1.000.000 centavos
    if (totalContributions >= 1000000) {
      await _unlockBadge('savings_milestone');
    }
  }

  // ── Longo prazo (6-12+ meses) ────────────────────────────────────────────

  Future<void> _checkYearStreak() async {
    final streak = await _streakRepository
        .watchStreakByType(StreakType.recording)
        .first;
    if (streak != null && streak.currentCount >= 365) {
      await _unlockBadge('year_streak');
    }
  }

  Future<void> _checkAllGoalsCompleted() async {
    final goals = await _goalRepository.watchAllGoals().first;
    final activeGoals = goals.where((g) => !g.isRecurring).toList();
    if (activeGoals.length < 3) return;
    final allCompleted = activeGoals.every(
      (g) => g.currentAmountInCents >= g.targetAmountInCents,
    );
    if (allCompleted) {
      await _unlockBadge('all_goals_completed');
    }
  }

  Future<void> _checkInvestmentGains() async {
    final investments = await _investmentRepository.watchAllInvestments().first;
    if (investments.isEmpty) return;
    final allPositive = investments.every((i) => i.currentYield >= 0);
    if (allPositive) {
      await _unlockBadge('investment_gains');
    }
  }

  Future<void> _checkFinancialFreedom() async {
    final accounts = await _accountRepository.watchAllAccounts().first;
    int totalBalance = 0;
    for (final a in accounts) {
      totalBalance += a.balance;
    }
    // R$ 50.000 = 5.000.000 centavos
    if (totalBalance >= 5000000) {
      await _unlockBadge('financial_freedom');
    }
  }

  Future<void> _checkConsistentSaver() async {
    // Verifica se o usuário economizou nos últimos 6 meses
    final now = DateTime.now();
    bool allMonthsPositive = true;

    for (int i = 0; i < 6; i++) {
      final month = now.month - i;
      final year = month <= 0 ? now.year - 1 : now.year;
      final adjustedMonth = month <= 0 ? month + 12 : month;

      final startOfMonth = DateTime(year, adjustedMonth, 1);
      final endOfMonth = DateTime(year, adjustedMonth + 1, 0, 23, 59, 59);

      final transactions = await _transactionRepository
          .watchTransactionsWithFilters(
            startDate: startOfMonth,
            endDate: endOfMonth,
            isCompleted: true,
          )
          .first;

      int totalIncome = 0;
      int totalExpense = 0;
      for (final t in transactions) {
        if (t.type == TransactionType.income) {
          totalIncome += t.amount;
        } else if (t.type == TransactionType.expense) {
          totalExpense += t.amount;
        }
      }

      // Se não tem transações no mês, pula (usuário pode ter começado há pouco)
      if (totalIncome == 0 && totalExpense == 0) continue;

      if (totalIncome <= totalExpense) {
        allMonthsPositive = false;
        break;
      }
    }

    if (allMonthsPositive) {
      await _unlockBadge('consistent_saver');
    }
  }

  void dispose() {
    _badgeUnlockController.close();
  }
}
