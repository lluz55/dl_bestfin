import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/accounts/domain/usecases/create_account.dart';
import 'package:bestfin/features/accounts/domain/usecases/delete_account.dart';
import 'package:bestfin/features/accounts/domain/usecases/update_account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:fl_chart/fl_chart.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return AccountRepositoryImpl(database);
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.watchAllAccounts();
});

final activeAccountsProvider = Provider<List<Account>>((ref) {
  final accountsAsync = ref.watch(accountsProvider);
  return accountsAsync.when(
    data: (list) => list.where((a) => a.isActive).toList(),
    loading: () => [],
    error: (_, _) => [],
  );
});

final totalBalanceProvider = Provider<int>((ref) {
  final activeList = ref.watch(activeAccountsProvider);
  return activeList.fold<int>(0, (sum, acc) => sum + acc.balance);
});

final accountByIdProvider = StreamProvider.family<Account, String>((ref, id) {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.watchAccountById(id);
});

final createAccountProvider = Provider<CreateAccount>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  return CreateAccount(repository);
});

final updateAccountProvider = Provider<UpdateAccount>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  return UpdateAccount(repository);
});

final deleteAccountProvider = Provider<DeleteAccount>((ref) {
  final repository = ref.watch(accountRepositoryProvider);
  return DeleteAccount(repository);
});

class AccountTransaction {
  final db.Transaction transaction;
  final db.Entry entry;
  const AccountTransaction(this.transaction, this.entry);
}

final accountTransactionsProvider =
    StreamProvider.family<List<AccountTransaction>, String>((ref, accountId) {
      final database = ref.watch(databaseProvider);
      final query =
          database.select(database.transactions).join([
              innerJoin(
                database.entries,
                database.entries.transactionId.equalsExp(
                  database.transactions.id,
                ),
              ),
            ])
            ..where(database.entries.accountId.equals(accountId))
            ..orderBy([
              OrderingTerm(
                expression: database.transactions.date,
                mode: OrderingMode.desc,
              ),
            ]);

      return query.watch().map((rows) {
        return rows.map((r) {
          final transaction = r.readTable(database.transactions);
          final entry = r.readTable(database.entries);
          return AccountTransaction(transaction, entry);
        }).toList();
      });
    });

final accountBalanceEvolutionProvider =
    StreamProvider.family<List<FlSpot>, String>((ref, accountId) {
      final database = ref.watch(databaseProvider);

      final query =
          database.select(database.entries).join([
              innerJoin(
                database.transactions,
                database.transactions.id.equalsExp(
                  database.entries.transactionId,
                ),
              ),
            ])
            ..where(database.entries.accountId.equals(accountId))
            ..orderBy([
              OrderingTerm(
                expression: database.transactions.date,
                mode: OrderingMode.asc,
              ),
            ]);

      return query.watch().map((rows) {
        List<FlSpot> spots = [];
        int balance = 0;

        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          final entry = row.readTable(database.entries);
          final transaction = row.readTable(database.transactions);

          final change = entry.type == 'debit' ? entry.amount : -entry.amount;
          balance += change;

          final dateMs = transaction.date.millisecondsSinceEpoch.toDouble();
          spots.add(FlSpot(dateMs, balance / 100.0));
        }

        return spots;
      });
    });

final initialBalanceProvider = FutureProvider.family<int, String>((
  ref,
  accountId,
) {
  final repository = ref.watch(accountRepositoryProvider);
  return repository.getInitialBalance(accountId);
});
