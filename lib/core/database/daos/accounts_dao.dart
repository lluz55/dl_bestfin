import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/accounts.dart';
import '../tables/entries.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts, Entries])
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

  Future<int> deleteAccount(String id) {
    return (delete(accounts)..where((t) => t.id.equals(id))).go();
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
