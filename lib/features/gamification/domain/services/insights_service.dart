import 'dart:async';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';
import 'package:bestfin/features/goals/data/repositories/goal_repository.dart';
import 'package:bestfin/features/investments/data/repositories/investment_repository.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/gamification/domain/models/financial_insight.dart';

class InsightsService {
  final TransactionRepository _transactionRepository;
  final AppDatabase _db;
  final GoalRepository _goalRepository;
  final InvestmentRepository _investmentRepository;

  InsightsService({
    required TransactionRepository transactionRepository,
    required AppDatabase db,
    required AccountRepository accountRepository,
    required GoalRepository goalRepository,
    required InvestmentRepository investmentRepository,
  })  : _transactionRepository = transactionRepository,
        _db = db,
        _goalRepository = goalRepository,
        _investmentRepository = investmentRepository;

  Future<List<InsightModel>> generateInsights() async {
    if (!await _transactionRepository.hasAnyTransactions()) {
      return [
        const InsightModel(
          text: 'Comece a registrar suas transações para ver insights aqui!',
          icon: '💡',
          category: InsightCategory.general,
        ),
      ];
    }

    final insights = <InsightModel>[];
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
    final thisMonth = await _transactionRepository
        .watchTransactionsWithFilters(
          startDate: startOfMonth,
          endDate: endOfMonth,
        )
        .first;

    final debtInsight = await _analyzeDebt();
    if (debtInsight != null) insights.add(debtInsight);

    final savingsInsight = await _analyzeSavings();
    if (savingsInsight != null) insights.add(savingsInsight);

    final budgetInsights = await _analyzeBudgets();
    insights.addAll(budgetInsights);

    final cashflowInsight = await _analyzeCashflow();
    if (cashflowInsight != null) insights.add(cashflowInsight);

    final investmentInsights = await _analyzeInvestments();
    insights.addAll(investmentInsights);

    final subscriptionInsight = await _analyzeSubscriptions();
    if (subscriptionInsight != null) insights.add(subscriptionInsight);

    final goalInsights = await _analyzeGoals();
    insights.addAll(goalInsights);

    final sentimentInsight = _analyzeSentiment(thisMonth);
    if (sentimentInsight != null) insights.add(sentimentInsight);

    final balanceInsight = _analyzeBalance(thisMonth);
    if (balanceInsight != null) insights.add(balanceInsight);

    final behaviorInsight = _analyzeBehavior(thisMonth);
    if (behaviorInsight != null) insights.add(behaviorInsight);

    if (insights.isEmpty) {
      insights.add(
        const InsightModel(
          text: 'Mantenha seus registros em dia para receber dicas personalizadas.',
          icon: '💡',
          category: InsightCategory.general,
        ),
      );
    }

    return insights;
  }

  InsightModel? _analyzeSentiment(List<dynamic> transactions) {
    final badSentiments = transactions.where(
      (t) {
        final sentiment = t.sentiment;
        if (sentiment == null) return false;
        final sentimentStr = sentiment.toString();
        return sentimentStr.contains('terrible') || sentimentStr.contains('bad');
      },
    );
    if (badSentiments.isNotEmpty) {
      final totalBad = badSentiments.fold<int>(0, (sum, t) => sum + (t.amount as int));
      if (totalBad > 0) {
        return InsightModel(
          text: 'Você gastou R\$ ${(totalBad / 100).toStringAsFixed(2)} em compras que te deixaram triste. Considere eliminá-las!',
          icon: '😞',
          category: InsightCategory.behavior,
        );
      }
    }
    return null;
  }

  InsightModel? _analyzeBalance(List<dynamic> transactions) {
    final income = transactions
        .where((t) => t.type == TransactionType.income)
        .fold<int>(0, (sum, t) => sum + (t.amount as int));
    final expense = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold<int>(0, (sum, t) => sum + (t.amount as int));

    if (income > expense && income > 0) {
      return const InsightModel(
        text: 'Parabéns! Você está gastando menos do que ganha este mês. Continue assim! 🎉',
        icon: '📈',
        category: InsightCategory.savings,
      );
    }
    return null;
  }

  InsightModel? _analyzeBehavior(List<dynamic> transactions) {
    final hasLazer = transactions.any(
      (t) => t.category?.name.toLowerCase().contains('lazer') ?? false,
    );
    if (!hasLazer && transactions.isNotEmpty) {
      return const InsightModel(
        text: 'Nenhum gasto em Lazer este mês. Lembre-se de reservar um tempo para você!',
        icon: '🏖️',
        category: InsightCategory.behavior,
      );
    }
    return null;
  }

  Future<FinancialInsight?> _analyzeDebt() async {
    final financings = await _db.financingsDao.watchAllFinancings().first;
    final totalDebt = financings.fold<int>(0, (sum, f) => sum + f.outstandingBalance);

    if (totalDebt > 0) {
      return FinancialInsight.debt(
        id: 'debt_${DateTime.now().millisecondsSinceEpoch}',
        message: 'Você tem R\$ ${(totalDebt / 100).toStringAsFixed(2)} em dívidas ativas. '
            'Priorize pagar as dívidas com juros mais altos.',
        totalDebt: totalDebt,
      );
    }
    return null;
  }

  Future<FinancialInsight?> _analyzeSavings() async {
    final goals = await _goalRepository.watchActiveGoals().first;
    final savingGoals = goals.where((g) => g.type.name == 'saving').toList();
    final activeSavings = savingGoals.where((g) => !g.isCompleted).toList();

    if (activeSavings.isEmpty) return null;

    final totalTarget = activeSavings.fold<int>(0, (sum, g) => sum + g.targetAmountInCents);
    final totalCurrent = activeSavings.fold<int>(0, (sum, g) => sum + g.currentAmountInCents);

    if (totalTarget == 0) return null;

    final progressPercent = (totalCurrent / totalTarget) * 100;

    if (progressPercent < 30) {
      return FinancialInsight.savings(
        id: 'savings_${DateTime.now().millisecondsSinceEpoch}',
        message: 'Você economizou apenas ${progressPercent.toStringAsFixed(0)}% do total das metas. '
            'Lembre-se de poupar regularmente!',
        progressPercent: progressPercent,
      );
    }
    return null;
  }

  Future<List<InsightModel>> _analyzeBudgets() async {
    final insights = <InsightModel>[];
    final now = DateTime.now();
    final budgets = await _db.budgetsDao.getByPeriod(now.year, now.month);

    if (budgets.isEmpty) return insights;

    final transactions = await _transactionRepository
        .watchTransactionsWithFilters(
          startDate: DateTime(now.year, now.month, 1),
          endDate: DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1)),
          isCompleted: true,
        )
        .first;

    for (final budget in budgets) {
      // Buscar categorias deste orçamento.
      final categoryIds = await _db.budgetsDao.getCategoryIdsForBudget(budget.id);

      // Filtrar transações que pertencem a qualquer categoria do orçamento.
      final expenseTx = transactions
          .where((tx) => tx.type == TransactionType.expense && categoryIds.contains(tx.categoryId))
          .fold<int>(0, (sum, tx) => sum + tx.amount);

      final overspent = expenseTx - budget.amount;
      if (overspent > 0) {
        insights.add(FinancialInsight.budget(
          id: 'budget_${budget.id}_${DateTime.now().millisecondsSinceEpoch}',
          message: 'Você gastou R\$ ${(overspent / 100).toStringAsFixed(2)} a mais do orçamento "${budget.name}".',
          categoryName: budget.name,
          overspentAmount: overspent,
        ));
      }
    }

    return insights;
  }

  Future<FinancialInsight?> _analyzeCashflow() async {
    final currentBalance = await _db.accountsDao.getConfirmedBalance();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));

    final pendingTxs = await _transactionRepository
        .watchTransactionsWithFilters(
          startDate: startOfMonth,
          endDate: endOfMonth,
          isCompleted: false,
        )
        .first;

    final pendingIncome = pendingTxs
        .where((tx) => tx.type == TransactionType.income)
        .fold<int>(0, (sum, tx) => sum + tx.amount);

    final pendingExpense = pendingTxs
        .where((tx) => tx.type == TransactionType.expense)
        .fold<int>(0, (sum, tx) => sum + tx.amount);

    final netPending = pendingIncome - pendingExpense;

    if (netPending < -10000) {
      return FinancialInsight.cashflow(
        id: 'cashflow_${DateTime.now().millisecondsSinceEpoch}',
        message: 'Seu saldo projetado no fim do mês pode ficar negativo. '
            'Evite gastos não essenciais de R\$ ${(-netPending / 100).toStringAsFixed(2)}.',
        projectedBalance: currentBalance + netPending,
      );
    }
    return null;
  }

  Future<List<InsightModel>> _analyzeInvestments() async {
    final insights = <InsightModel>[];
    final investments = await _investmentRepository.watchAllInvestments().first;

    if (investments.isEmpty) return insights;

    final negativeYieldInvestments = investments.where((i) => i.currentYield < 0).toList();
    if (negativeYieldInvestments.isNotEmpty) {
      final totalLoss = negativeYieldInvestments.fold<int>(0, (sum, i) => sum + i.currentYield);
      insights.add(FinancialInsight.investment(
        id: 'investment_loss_${DateTime.now().millisecondsSinceEpoch}',
        message: 'Você tem R\$ ${(-totalLoss / 100).toStringAsFixed(2)} em investimentos com perda. '
            'Considere reavaliar sua estratégia.',
        investmentType: 'Perdidos',
        changeAmount: totalLoss,
      ));
    }

    return insights;
  }

  Future<FinancialInsight?> _analyzeSubscriptions() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final transactions = await _transactionRepository.watchAllTransactions().first;

    final subscriptionCategories = ['cat_subscription', 'cat_streaming', 'cat_software'];
    final subscriptionTxs = transactions.where((tx) {
      if (!subscriptionCategories.contains(tx.categoryId)) return false;
      if (tx.date.isBefore(startOfMonth)) return false;
      return tx.type == TransactionType.expense;
    }).toList();

    if (subscriptionTxs.isEmpty) return null;

    final totalMonthly = subscriptionTxs.fold<int>(0, (sum, tx) => sum + tx.amount);
    final uniqueMerchants = subscriptionTxs.map((tx) => tx.description).toSet();

    return FinancialInsight.subscription(
      id: 'subscriptions_${DateTime.now().millisecondsSinceEpoch}',
      message: 'Você tem ${uniqueMerchants.length} serviços com cobrança este mês, '
          'totalizando R\$ ${(totalMonthly / 100).toStringAsFixed(2)}. Revise se todos estão sendo usados.',
      monthlyCost: totalMonthly,
    );
  }

  Future<List<InsightModel>> _analyzeGoals() async {
    final insights = <InsightModel>[];
    final goals = await _goalRepository.watchActiveGoals().first;

    for (final goal in goals) {
      if (goal.isCompleted) continue;

      final monthsRemaining = goal.monthsRemaining;

      if (monthsRemaining != null && monthsRemaining <= 0) {
        insights.add(FinancialInsight.goal(
          id: 'goal_overdue_${goal.id}',
          message: 'Sua meta "${goal.name}" já venceu. Atualize o prazo ou aumente o valor mensal.',
          goal: goal,
        ));
      } else if (monthsRemaining != null && monthsRemaining <= 3 && goal.type.name == 'saving') {
        final monthlyTarget = goal.monthlyTargetInCents ?? 0;
        insights.add(FinancialInsight.goal(
          id: 'goal_final_push_${goal.id}',
          message: 'Faltam $monthsRemaining mes(es) para sua meta "${goal.name}". '
              'Reserve R\$ ${(monthlyTarget / 100).toStringAsFixed(2)}/mês para completá-la.',
          goal: goal,
        ));
      }
    }

    return insights;
  }
}