import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/core/constants/transaction_types.dart';

class GenerateCashFlow {
  final TransactionRepository _repository;

  GenerateCashFlow(this._repository);

  Stream<CashFlowReport> call({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? accountIds,
    List<String>? creditCardIds,
  }) {
    return _repository
        .watchTransactionsWithFilters(
          accountIds: accountIds,
          creditCardIds: creditCardIds,
          startDate: startDate,
          endDate: endDate,
        )
        .map((transactions) {
          final completed = transactions.where((tx) => tx.isCompleted).toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          // Group by day
          final Map<String, _DayGroup> dayMap = {};
          for (final tx in completed) {
            if (tx.type == TransactionType.transfer) continue;
            final key =
                '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
            final g = dayMap[key] ?? _DayGroup(tx.date, 0, 0);
            if (tx.type == TransactionType.income) {
              dayMap[key] = _DayGroup(g.date, g.income + tx.amount, g.expense);
            } else {
              dayMap[key] = _DayGroup(g.date, g.income, g.expense + tx.amount);
            }
          }

          final days = dayMap.values.toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          int cumulative = 0;
          int totalIncome = 0;
          int totalExpense = 0;
          final points = <CashFlowPoint>[];

          for (final day in days) {
            cumulative += day.income - day.expense;
            totalIncome += day.income;
            totalExpense += day.expense;
            points.add(
              CashFlowPoint(
                date: day.date,
                income: day.income,
                expense: day.expense,
                cumulativeBalance: cumulative,
              ),
            );
          }

          return CashFlowReport(
            points: points,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
          );
        });
  }
}

class _DayGroup {
  final DateTime date;
  final int income;
  final int expense;
  const _DayGroup(this.date, this.income, this.expense);
}
