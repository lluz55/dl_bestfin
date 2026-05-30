import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/accounts.dart';
import '../tables/entries.dart';
import '../tables/transactions.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts, Entries, Transactions])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(AppDatabase db) : super(db);

  Stream<List<Account>> watchAllAccounts() {
    return select(accounts).watch();
  }

  Future<Account> getAccountById(String id) {
    return (select(accounts)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> insertAccount(AccountsCompanion account) {
    return into(accounts).insert(account);
  }

  Future<bool> updateAccount(AccountsCompanion account) {
    return update(accounts).replace(account);
  }

  Future<void> deleteAccount(String id) async {
    await db.transaction(() async {
      // Find all transactions with entries linked to this account
      final transactionIds =
          await (selectOnly(entries)
                ..addColumns([entries.transactionId])
                ..where(entries.accountId.equals(id)))
              .map((row) => row.read(entries.transactionId)!)
              .get();

      // Delete those transactions (cascade removes their entries)
      if (transactionIds.isNotEmpty) {
        await (delete(
          transactions,
        )..where((t) => t.id.isIn(transactionIds))).go();
      }

      await (delete(accounts)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Calculates the current balance of an account by summing its entries
  Stream<int> watchAccountBalance(String accountId) {
    final balanceExpr = CustomExpression<int>(
      "SUM(CASE WHEN type = 'debit' THEN amount ELSE -amount END)",
    );

    final query = selectOnly(entries)
      ..addColumns([balanceExpr])
      ..where(entries.accountId.equals(accountId));

    return query.map((row) => row.read(balanceExpr) ?? 0).watchSingle();
  }
}
