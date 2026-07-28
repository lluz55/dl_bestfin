import 'package:bestfin/features/goals/domain/models/goal.dart';

enum InsightCategory {
  debt,
  savings,
  budget,
  cashflow,
  investment,
  creditCard,
  subscription,
  goal,
  behavior,
  general;
}

class InsightModel {
  final String text;
  final String icon;
  final String? actionLabel;
  final String? actionRoute;
  final InsightCategory? category;

  const InsightModel({
    required this.text,
    required this.icon,
    this.actionLabel,
    this.actionRoute,
    this.category,
  });
}

class FinancialInsight extends InsightModel {
  final String id;
  final String title;
  final int? relatedAmount;
  final DateTime createdAt;

  const FinancialInsight({
    required this.id,
    required this.title,
    required String message,
    required String insightIcon,
    required InsightCategory insightCategory,
    this.relatedAmount,
    required this.createdAt,
  }) : super(text: message, icon: insightIcon, category: insightCategory);

  factory FinancialInsight.debt({
    required String id,
    required String message,
    required int totalDebt,
  }) {
    return FinancialInsight(
      id: id,
      title: 'Gestão de Dívidas',
      message: message,
      insightIcon: '📉',
      insightCategory: InsightCategory.debt,
      relatedAmount: totalDebt,
      createdAt: DateTime.now(),
    );
  }

  factory FinancialInsight.savings({
    required String id,
    required String message,
    required double progressPercent,
  }) {
    return FinancialInsight(
      id: id,
      title: 'Economia',
      message: message,
      insightIcon: '💰',
      insightCategory: InsightCategory.savings,
      createdAt: DateTime.now(),
    );
  }

  factory FinancialInsight.budget({
    required String id,
    required String message,
    required String categoryName,
    required int overspentAmount,
  }) {
    return FinancialInsight(
      id: id,
      title: 'Orçamento',
      message: message,
      insightIcon: '📊',
      insightCategory: InsightCategory.budget,
      relatedAmount: overspentAmount,
      createdAt: DateTime.now(),
    );
  }

  factory FinancialInsight.cashflow({
    required String id,
    required String message,
    required int projectedBalance,
  }) {
    return FinancialInsight(
      id: id,
      title: 'Fluxo de Caixa',
      message: message,
      insightIcon: '💳',
      insightCategory: InsightCategory.cashflow,
      relatedAmount: projectedBalance,
      createdAt: DateTime.now(),
    );
  }

  factory FinancialInsight.investment({
    required String id,
    required String message,
    required String investmentType,
    required int changeAmount,
  }) {
    return FinancialInsight(
      id: id,
      title: 'Investimentos',
      message: message,
      insightIcon: '📈',
      insightCategory: InsightCategory.investment,
      relatedAmount: changeAmount,
      createdAt: DateTime.now(),
    );
  }

  factory FinancialInsight.creditCard({
    required String id,
    required String message,
    required String cardName,
    required int invoiceAmount,
  }) {
    return FinancialInsight(
      id: id,
      title: 'Cartão de Crédito',
      message: message,
      insightIcon: '💳',
      insightCategory: InsightCategory.creditCard,
      relatedAmount: invoiceAmount,
      createdAt: DateTime.now(),
    );
  }

  factory FinancialInsight.subscription({
    required String id,
    required String message,
    required int monthlyCost,
  }) {
    return FinancialInsight(
      id: id,
      title: 'Assinaturas',
      message: message,
      insightIcon: '🔔',
      insightCategory: InsightCategory.subscription,
      relatedAmount: monthlyCost,
      createdAt: DateTime.now(),
    );
  }

  factory FinancialInsight.goal({
    required String id,
    required String message,
    required GoalModel goal,
  }) {
    return FinancialInsight(
      id: id,
      title: 'Metas Financeiras',
      message: message,
      insightIcon: '🎯',
      insightCategory: InsightCategory.goal,
      createdAt: DateTime.now(),
    );
  }

  factory FinancialInsight.behavior({
    required String id,
    required String message,
    required String pattern,
  }) {
    return FinancialInsight(
      id: id,
      title: 'Comportamento',
      message: message,
      insightIcon: '🧠',
      insightCategory: InsightCategory.behavior,
      createdAt: DateTime.now(),
    );
  }
}