import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/accounts.dart';
import 'package:bestfin/core/database/tables/entries.dart';
import 'package:bestfin/core/database/tables/transactions.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts, Entries, Transactions])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

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
    const balanceExpr = CustomExpression<int>(
      "SUM(CASE WHEN type = 'debit' THEN amount ELSE -amount END)",
    );

    final query = selectOnly(entries)
      ..addColumns([balanceExpr])
      ..where(entries.accountId.equals(accountId));

    return query.map((row) => row.read(balanceExpr) ?? 0).watchSingle();
  }

  /// Sums the balance across every account in a single query, instead of
  /// running one [watchAccountBalance] query per account.
  Future<int> getTotalBalance() async {
    const balanceExpr = CustomExpression<int>(
      "SUM(CASE WHEN type = 'debit' THEN amount ELSE -amount END)",
    );

    final query = selectOnly(entries)..addColumns([balanceExpr]);
    final row = await query.getSingle();
    return row.read(balanceExpr) ?? 0;
  }

  /// Saldo apenas de transações já ocorridas e confirmadas (exclui
  /// pendentes/futuras). Usado como ponto de partida de projeções de fluxo de
  /// caixa, para não contar pendentes duas vezes — uma no saldo "atual",
  /// outra nos deltas diários somados ao longo da janela de projeção. Ver
  /// [getTotalBalance], que deliberadamente inclui pendentes para telas que
  /// mostram saldo disponível "com pendentes embutidos" (ex.: freeToSpend).
  Future<int> getConfirmedBalance() async {
    const balanceExpr = CustomExpression<int>(
      "SUM(CASE WHEN entries.type = 'debit' THEN entries.amount ELSE -entries.amount END)",
    );

    final query = selectOnly(entries)
      ..addColumns([balanceExpr])
      ..join([
        innerJoin(
          transactions,
          transactions.id.equalsExp(entries.transactionId),
        ),
      ])
      ..where(
        transactions.isCompleted.equals(true) &
            transactions.isConfirmed.equals(true),
      );
    final row = await query.getSingleOrNull();
    return row?.read(balanceExpr) ?? 0;
  }
}
