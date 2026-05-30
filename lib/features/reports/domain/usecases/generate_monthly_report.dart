import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/core/constants/transaction_types.dart';

class GenerateMonthlyReport {
  final TransactionRepository _repository;

  GenerateMonthlyReport(this._repository);

  Stream<MonthlyReport> call({
    int months = 6,
    List<String>? accountIds,
    List<String>? creditCardIds,
  }) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months + 1, 1);
    final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return _repository
        .watchTransactionsWithFilters(
          accountIds: accountIds,
          creditCardIds: creditCardIds,
          startDate: startDate,
          endDate: endDate,
        )
        .map((transactions) {
          final Map<String, MonthlyBar> barMap = {};

          for (int i = 0; i < months; i++) {
            final d = DateTime(now.year, now.month - (months - 1 - i), 1);
            final key = '${d.year}-${d.month}';
            barMap[key] = MonthlyBar(
              year: d.year,
              month: d.month,
              income: 0,
              expense: 0,
            );
          }

          for (final tx in transactions) {
            if (!tx.isCompleted) continue;
            final key = '${tx.date.year}-${tx.date.month}';
            final bar = barMap[key];
            if (bar == null) continue;

            if (tx.type == TransactionType.income) {
              barMap[key] = MonthlyBar(
                year: bar.year,
                month: bar.month,
                income: bar.income + tx.amount,
                expense: bar.expense,
              );
            } else if (tx.type == TransactionType.expense) {
              barMap[key] = MonthlyBar(
                year: bar.year,
                month: bar.month,
                income: bar.income,
                expense: bar.expense + tx.amount,
              );
            }
          }

          final bars = barMap.values.toList()
            ..sort((a, b) {
              final da = DateTime(a.year, a.month);
              final db = DateTime(b.year, b.month);
              return da.compareTo(db);
            });

          return MonthlyReport(bars: bars);
        });
  }
}
