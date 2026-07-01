import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/cashflow/domain/models/cashflow_projection.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';

class CalculateCashFlowProjection {
  final AppDatabase db;
  final TransactionRepository transactionRepository;

  const CalculateCashFlowProjection({
    required this.db,
    required this.transactionRepository,
  });

  Future<CashFlowProjection> call({int days = 90}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final windowEnd = today.add(Duration(days: days));

    // 1. Current balance across all accounts
    final accounts = await db.accountsDao.watchAllAccounts().first;
    int currentBalance = 0;
    for (final acc in accounts) {
      currentBalance += await db.accountsDao.watchAccountBalance(acc.id).first;
    }

    // 2. Future incomplete transactions (recurring instances, bills, etc.)
    final Map<DateTime, int> dailyNet = {};
    final allTxs = await transactionRepository.watchAllTransactions().first;
    for (final tx in allTxs) {
      if (tx.isCompleted) continue;
      final d = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (d.isBefore(today) || d.isAfter(windowEnd)) continue;
      final isIncome = tx.type == TransactionType.income;
      final isExpense = tx.type == TransactionType.expense;
      if (!isIncome && !isExpense) continue;
      final delta = isIncome ? tx.amount : -tx.amount;
      dailyNet[d] = (dailyNet[d] ?? 0) + delta;
    }

    // 3. Unpaid financing installments in the window
    final financings = await db.financingsDao.watchAllFinancings().first;
    for (final financing in financings) {
      final installments = await db.financingsDao.getInstallmentsForFinancing(
        financing.id,
      );
      for (final inst in installments) {
        if (inst.paidDate != null) continue;
        final d = DateTime(
          inst.dueDate.year,
          inst.dueDate.month,
          inst.dueDate.day,
        );
        if (d.isBefore(today) || d.isAfter(windowEnd)) continue;
        dailyNet[d] = (dailyNet[d] ?? 0) - inst.totalValue;
      }
    }

    // 4. Build projection points day-by-day
    final points = <CashFlowProjectionPoint>[];
    int runningBalance = currentBalance;
    for (int i = 0; i < days; i++) {
      final date = today.add(Duration(days: i));
      final net = dailyNet[date] ?? 0;
      runningBalance += net;
      points.add(
        CashFlowProjectionPoint(
          date: date,
          cumulativeBalance: runningBalance,
          dailyNet: net,
        ),
      );
    }

    return CashFlowProjection(
      currentBalance: currentBalance,
      points: points,
      projectedBalance30d: points.length >= 30
          ? points[29].cumulativeBalance
          : points.last.cumulativeBalance,
      projectedBalance60d: points.length >= 60
          ? points[59].cumulativeBalance
          : points.last.cumulativeBalance,
      projectedBalance90d: points.last.cumulativeBalance,
    );
  }
}
