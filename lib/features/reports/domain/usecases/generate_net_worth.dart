import 'dart:async';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/core/constants/transaction_types.dart';

class GenerateNetWorth {
  final TransactionRepository _transactionRepository;
  final AccountRepository _accountRepository;
  final db.AppDatabase _database;

  GenerateNetWorth({
    required TransactionRepository transactionRepository,
    required AccountRepository accountRepository,
    required db.AppDatabase database,
  }) : _transactionRepository = transactionRepository,
       _accountRepository = accountRepository,
       _database = database;

  Stream<NetWorthReport> call({int months = 6}) {
    final now = DateTime.now();
    final controller = StreamController<NetWorthReport>();

    StreamSubscription? subAcc;
    StreamSubscription? subInv;
    StreamSubscription? subFin;
    StreamSubscription? subTx;

    List<Account>? lastAcc;
    List<db.Investment>? lastInv;
    List<db.Financing>? lastFin;
    List<TransactionModel>? lastTx;

    void update() {
      if (lastAcc != null &&
          lastInv != null &&
          lastFin != null &&
          lastTx != null) {
        try {
          final totalAccounts = lastAcc!
              .where((a) => a.isActive)
              .fold<int>(0, (sum, a) => sum + a.balance);

          final totalInvestments = lastInv!.fold<int>(
            0,
            (sum, inv) => sum + inv.investedAmount + inv.currentYield,
          );

          final totalFinancings = lastFin!.fold<int>(
            0,
            (sum, fin) => sum + fin.outstandingBalance,
          );

          final currentNetWorth =
              totalAccounts + totalInvestments - totalFinancings;

          final completed = lastTx!.where((tx) => tx.isCompleted).toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          final Map<String, int> monthlyNet = {};
          for (int i = 0; i < months; i++) {
            final d = DateTime(now.year, now.month - (months - 1 - i), 1);
            final key = '${d.year}-${d.month}';
            monthlyNet[key] = 0;
          }

          for (final tx in completed) {
            if (tx.type == TransactionType.transfer) continue;
            final key = '${tx.date.year}-${tx.date.month}';
            if (!monthlyNet.containsKey(key)) continue;
            if (tx.type == TransactionType.income) {
              monthlyNet[key] = monthlyNet[key]! + tx.amount;
            } else if (tx.type == TransactionType.expense) {
              monthlyNet[key] = monthlyNet[key]! - tx.amount;
            }
          }

          final keys = monthlyNet.keys.toList()
            ..sort((a, b) {
              final pa = a.split('-');
              final pb = b.split('-');
              return DateTime(
                int.parse(pa[0]),
                int.parse(pa[1]),
              ).compareTo(DateTime(int.parse(pb[0]), int.parse(pb[1])));
            });

          final List<int> monthEndValues = List.filled(months, 0);
          monthEndValues[months - 1] = currentNetWorth;
          for (int i = months - 2; i >= 0; i--) {
            final futureKey = keys[i + 1];
            monthEndValues[i] =
                monthEndValues[i + 1] - (monthlyNet[futureKey] ?? 0);
          }

          final points = <NetWorthPoint>[];
          for (int i = 0; i < keys.length; i++) {
            final parts = keys[i].split('-');
            points.add(
              NetWorthPoint(
                date: DateTime(int.parse(parts[0]), int.parse(parts[1])),
                netWorth: monthEndValues[i],
              ),
            );
          }

          final previousNetWorth = points.length >= 2
              ? points[points.length - 2].netWorth
              : currentNetWorth;

          if (!controller.isClosed) {
            controller.add(
              NetWorthReport(
                points: points,
                currentNetWorth: currentNetWorth,
                previousNetWorth: previousNetWorth,
              ),
            );
          }
        } catch (e, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(e, stackTrace);
          }
        }
      }
    }

    subAcc = _accountRepository.watchAllAccounts().listen(
      (accs) {
        lastAcc = accs;
        update();
      },
      onError: (err) {
        if (!controller.isClosed) controller.addError(err);
      },
    );

    subInv = _database.investmentsDao.watchAllInvestments().listen(
      (invs) {
        lastInv = invs;
        update();
      },
      onError: (err) {
        if (!controller.isClosed) controller.addError(err);
      },
    );

    subFin = _database.financingsDao.watchAllFinancings().listen(
      (fins) {
        lastFin = fins;
        update();
      },
      onError: (err) {
        if (!controller.isClosed) controller.addError(err);
      },
    );

    final startDate = DateTime(now.year, now.month - months + 1, 1);
    final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    subTx = _transactionRepository
        .watchTransactionsWithFilters(startDate: startDate, endDate: endDate)
        .listen(
          (txs) {
            lastTx = txs;
            update();
          },
          onError: (err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );

    controller.onCancel = () {
      subAcc?.cancel();
      subInv?.cancel();
      subFin?.cancel();
      subTx?.cancel();
    };

    return controller.stream;
  }
}
