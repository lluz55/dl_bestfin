import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';

class DashboardCategorySpending {
  final CategoryModel? category;
  final int amountInCents;
  final double percentage;

  const DashboardCategorySpending({
    required this.category,
    required this.amountInCents,
    required this.percentage,
  });

  // Usa displayName ('Pai/Filho' quando é subcategoria) para desambiguar
  // categorias comparadas nos gráficos.
  String get categoryName => category?.displayName ?? 'Sem Categoria';
}

class CategoryRankingItem {
  final CategoryModel? category;
  final int amountInCents;
  final double percentage;

  const CategoryRankingItem({
    this.category,
    required this.amountInCents,
    required this.percentage,
  });
}

class DashboardData {
  final int totalBalance;
  final int monthlyIncome;
  final int monthlyExpense;
  final List<DashboardCategorySpending> categoryExpenses;
  final List<TransactionModel> recentTransactions;
  final int freeToSpendAmount;
  final double freeToSpendPercentage;
  final List<TransactionModel> upcomingTransactions;
  final List<GoalModel> activeGoals;
  final List<MonthlyBar> monthlyHistory;
  final List<NetWorthPoint> netWorthHistory;
  final List<CashFlowPoint> cashFlowHistory;
  final List<CategoryRankingItem> categoryRanking;

  const DashboardData({
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.categoryExpenses,
    required this.recentTransactions,
    required this.freeToSpendAmount,
    required this.freeToSpendPercentage,
    required this.upcomingTransactions,
    required this.activeGoals,
    required this.monthlyHistory,
    required this.netWorthHistory,
    required this.cashFlowHistory,
    required this.categoryRanking,
  });
}
