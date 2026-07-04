import 'package:bestfin/features/categories/domain/models/category.dart';

class CategorySpending {
  final CategoryModel? category;
  final int amountInCents;
  final double percentage;

  /// Gasto "previsto" (transações futuras/pendentes) da categoria dentro do
  /// mesmo período. Não entra em [amountInCents]/[percentage].
  final int pendingAmountInCents;

  const CategorySpending({
    this.category,
    required this.amountInCents,
    required this.percentage,
    this.pendingAmountInCents = 0,
  });
}

class CategoryReport {
  final List<CategorySpending> items;
  final int totalExpense;
  final DateTime startDate;
  final DateTime endDate;

  const CategoryReport({
    required this.items,
    required this.totalExpense,
    required this.startDate,
    required this.endDate,
  });
}

class MonthlyBar {
  final int year;
  final int month;
  final int income;
  final int expense;

  /// Receita/despesa "previstas" (transações futuras/pendentes) do mês,
  /// exibidas como camada adicional — não somadas a [income]/[expense].
  final int pendingIncome;
  final int pendingExpense;

  const MonthlyBar({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    this.pendingIncome = 0,
    this.pendingExpense = 0,
  });

  int get net => income - expense;
  String get label {
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return months[month - 1];
  }
}

class MonthlyReport {
  final List<MonthlyBar> bars;

  const MonthlyReport({required this.bars});
}

class CashFlowPoint {
  final DateTime date;
  final int income;
  final int expense;
  final int cumulativeBalance;

  /// Receita/despesa "previstas" (transações futuras/pendentes) do dia,
  /// exibidas como camada adicional — não somadas a [income]/[expense].
  final int pendingIncome;
  final int pendingExpense;

  const CashFlowPoint({
    required this.date,
    required this.income,
    required this.expense,
    required this.cumulativeBalance,
    this.pendingIncome = 0,
    this.pendingExpense = 0,
  });
}

class CashFlowReport {
  final List<CashFlowPoint> points;
  final int totalIncome;
  final int totalExpense;

  const CashFlowReport({
    required this.points,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class NetWorthPoint {
  final DateTime date;
  final int netWorth;

  const NetWorthPoint({required this.date, required this.netWorth});
}

class NetWorthReport {
  final List<NetWorthPoint> points;
  final int currentNetWorth;
  final int previousNetWorth;

  const NetWorthReport({
    required this.points,
    required this.currentNetWorth,
    required this.previousNetWorth,
  });

  double get changePercent {
    if (previousNetWorth == 0) return 0;
    return ((currentNetWorth - previousNetWorth) / previousNetWorth.abs()) *
        100;
  }
}

class HeatmapCell {
  final int weekday; // 1=Mon..7=Sun
  final int hour; // 0–23
  final int totalAmount;
  final int count;

  const HeatmapCell({
    required this.weekday,
    required this.hour,
    required this.totalAmount,
    required this.count,
  });
}

class TreemapNode {
  final String id;
  final String label;
  final int value;
  final String color;
  final List<TreemapNode> children;

  const TreemapNode({
    required this.id,
    required this.label,
    required this.value,
    required this.color,
    this.children = const [],
  });
}
