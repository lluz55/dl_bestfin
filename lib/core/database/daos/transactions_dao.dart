import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transactions.dart';
import '../tables/entries.dart';
import 'package:uuid/uuid.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions, Entries])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(AppDatabase db) : super(db);

  Stream<List<Transaction>> watchAllTransactions() {
    return (select(transactions)
          ..where((t) => t.isConfirmed.equals(true))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<Transaction>> watchSuggestedTransactions() {
    return (select(transactions)
          ..where((t) => t.isConfirmed.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<void> confirmTransaction(String id) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      const TransactionsCompanion(isConfirmed: Value(true)),
    );
  }

  Future<Transaction> getTransactionById(String id) {
    return (select(transactions)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Partida dobrada (Double-entry accounting):
  /// Para despesa: credit da conta e debit da despesa (categoria).
  /// Porém o entries só mapeia Accounts. Então por enquanto
  /// armazenaremos apenas os entries das Accounts, pois nossa Tabela Entries
  /// requer `accountId` (que aponta para Accounts).
  ///
  /// Como o Entry exige `accountId` apontando pra uma Account real,
  /// a contabilidade dupla estrita precisaria que as categorias de Despesa/Receita
  /// também fossem "Contas Contábeis", ou permitisse `accountId` nulo para a contrapartida.
  ///
  /// Vamos rever essa abordagem: O modelo pede 2 entries com 'accountId'.
  /// Se é um pagamento, sai da Conta Corrente. O entry será 'credit' na Conta Corrente.
  /// A contrapartida seria a Categoria, mas Entry exige accountId.
  /// Como Entry restringe a Account, usaremos uma solução de Single-Entry pra conta
  /// mas com 2 registros apenas em transferências?
  /// A documentação pede exatamente 2 entries com account_id.
  /// A contrapartida requer a remoção do restrict para accountId ou a conta de contrapartida será ignorada.
  /// Vou gerar o insert transaction simples para que possamos adaptar.

  Future<void> createTransaction({
    required TransactionsCompanion data,
    required String accountId,
    required int amount,
    String? toAccountId, // For transfers
  }) async {
    await transaction(() async {
      final transactionId = const Uuid().v4();
      final type = data.type.value; // income, expense, transfer

      await into(transactions).insert(data.copyWith(id: Value(transactionId)));

      if (type == 'expense') {
        // Credit the source account
        await into(entries).insert(
          EntriesCompanion.insert(
            id: const Uuid().v4(),
            transactionId: transactionId,
            accountId: accountId,
            amount: amount,
            type: 'credit', // credit decreases assets
          ),
        );
        // Note: Full double entry would add a debit to an expense account,
        // but we only track asset accounts in the Accounts table currently.
      } else if (type == 'income') {
        // Debit the destination account
        await into(entries).insert(
          EntriesCompanion.insert(
            id: const Uuid().v4(),
            transactionId: transactionId,
            accountId: accountId,
            amount: amount,
            type: 'debit', // debit increases assets
          ),
        );
      } else if (type == 'transfer' && toAccountId != null) {
        // Credit source
        await into(entries).insert(
          EntriesCompanion.insert(
            id: const Uuid().v4(),
            transactionId: transactionId,
            accountId: accountId,
            amount: amount,
            type: 'credit',
          ),
        );
        // Debit destination
        await into(entries).insert(
          EntriesCompanion.insert(
            id: const Uuid().v4(),
            transactionId: transactionId,
            accountId: toAccountId,
            amount: amount,
            type: 'debit',
          ),
        );
      }
    });
  }

  Future<int> deleteTransaction(String id) {
    return (delete(transactions)..where((t) => t.id.equals(id))).go();
  }
}
