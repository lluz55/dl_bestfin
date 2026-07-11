import 'package:bestfin/core/database/app_database.dart' as db;

class CategoryInfo {
  final String id;
  final String name;
  final String? color;
  final String? icon;

  const CategoryInfo({
    required this.id,
    required this.name,
    this.color,
    this.icon,
  });
}

class BudgetModel {
  final String id;
  final String name;
  final List<String> categoryIds;
  final List<CategoryInfo> categories;
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
    required this.name,
    required this.categoryIds,
    required this.categories,
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

  /// Cor principal: cor da primeira categoria, ou null.
  String? get categoryColor =>
      categories.isNotEmpty ? categories.first.color : null;

  /// Ícone principal: ícone da primeira categoria, ou null.
  String? get categoryIcon =>
      categories.isNotEmpty ? categories.first.icon : null;

  /// Nome de exibição: primeira categoria ou nome do orçamento.
  String get displayName =>
      categories.length == 1 ? categories.first.name : name;

  factory BudgetModel.fromDbWithSpending(
    db.Budget budget,
    int spent, {
    int pending = 0,
    required List<String> categoryIds,
    required List<CategoryInfo> categories,
  }) {
    return BudgetModel(
      id: budget.id,
      name: budget.name,
      categoryIds: categoryIds,
      categories: categories,
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
