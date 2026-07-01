import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/ai/presentation/providers/ai_provider.dart';

class BudgetPaceAlert {
  final String categoryId;
  final String categoryName;
  final String categoryColor;
  final String categoryIcon;
  final int currentMonthSpend;
  final int projectedMonthTotal;
  final int historicalAverage;
  final double overspendPercent;
  final int daysRemaining;

  const BudgetPaceAlert({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.currentMonthSpend,
    required this.projectedMonthTotal,
    required this.historicalAverage,
    required this.overspendPercent,
    required this.daysRemaining,
  });
}

final budgetPacingProvider = Provider<List<BudgetPaceAlert>>((ref) {
  final txsAsync = ref.watch(filteredTransactionsProvider);
  final budgetRecs = ref.watch(budgetRecommendationsProvider);

  return txsAsync.when(
    data: (txs) {
      if (budgetRecs.isEmpty) return [];

      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
      final daysElapsed = now.day;
      final daysRemaining = lastDayOfMonth - now.day;

      if (daysElapsed == 0) return [];

      final Map<String, int> currentSpend = {};
      for (final tx in txs) {
        if (tx.categoryId == null) continue;
        if (!tx.isCompleted || tx.type != TransactionType.expense) continue;
        if (tx.date.isBefore(currentMonthStart)) continue;
        currentSpend[tx.categoryId!] =
            (currentSpend[tx.categoryId!] ?? 0) + tx.amount;
      }

      final List<BudgetPaceAlert> alerts = [];

      for (final rec in budgetRecs) {
        final current = currentSpend[rec.categoryId] ?? 0;
        if (current == 0) continue;

        final dailyRate = current / daysElapsed;
        final projected = (current + dailyRate * daysRemaining).round();
        final historical = rec.avgMonthlySpend;
        if (historical == 0) continue;

        if (projected > historical * 1.15) {
          final overspend = (projected - historical) / historical * 100;
          alerts.add(
            BudgetPaceAlert(
              categoryId: rec.categoryId,
              categoryName: rec.categoryName,
              categoryColor: rec.categoryColor,
              categoryIcon: rec.categoryIcon,
              currentMonthSpend: current,
              projectedMonthTotal: projected,
              historicalAverage: historical,
              overspendPercent: overspend,
              daysRemaining: daysRemaining,
            ),
          );
        }
      }

      alerts.sort((a, b) => b.overspendPercent.compareTo(a.overspendPercent));
      return alerts;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
