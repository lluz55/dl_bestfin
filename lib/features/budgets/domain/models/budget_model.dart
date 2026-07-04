import 'package:bestfin/core/database/app_database.dart' as db;

class BudgetModel {
  final String id;
  final String categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  final int year;
  final int month;
  final int amount;
  final int rolloverAmount;
  final int spent;

  /// Gasto "previsto" — transações futuras/pendentes dentro do período que
  /// ainda não ocorreram. Não entra em [spent]/[progress]/[isOverBudget].
  final int pending;
  final DateTime createdAt;

  const BudgetModel({
    required this.id,
    required this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
    required this.year,
    required this.month,
    required this.amount,
    required this.rolloverAmount,
    required this.spent,
    this.pending = 0,
    required this.createdAt,
  });

  int get totalBudget => amount + rolloverAmount;
  int get available => totalBudget - spent;
  double get progress => totalBudget == 0 ? 0.0 : spent / totalBudget;
  bool get isOverBudget => spent > totalBudget;

  /// Gasto confirmado + previsto, para exibir a projeção do período.
  int get projectedSpent => spent + pending;
  double get projectedProgress =>
      totalBudget == 0 ? 0.0 : projectedSpent / totalBudget;

  factory BudgetModel.fromDbWithSpending(
    db.Budget budget,
    int spent, {
    int pending = 0,
    String? categoryName,
    String? categoryColor,
    String? categoryIcon,
  }) {
    return BudgetModel(
      id: budget.id,
      categoryId: budget.categoryId,
      categoryName: categoryName,
      categoryColor: categoryColor,
      categoryIcon: categoryIcon,
      year: budget.year,
      month: budget.month,
      amount: budget.amount,
      rolloverAmount: budget.rolloverAmount,
      spent: spent,
      pending: pending,
      createdAt: budget.createdAt,
    );
  }
}
