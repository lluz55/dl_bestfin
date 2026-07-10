import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/models/bulk_transaction_item.dart';
import 'package:bestfin/features/transactions/domain/usecases/create_transactions_bulk.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> insertAccount(String name) async {
    final id = const Uuid().v4();
    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(id: id, name: name, type: 'checking'),
    );
    return id;
  }

  test(
    'createTransactionsBulk inserts N transactions with correct entries',
    () async {
      final accountId = await insertAccount('Checking');
      final toAccountId = await insertAccount('Savings');
      final date = DateTime.now();

      final ids = await repository.createTransactionsBulk([
        BulkTransactionItem(
          date: date,
          description: 'Mercado',
          type: 'expense',
          amount: 5000,
          accountId: accountId,
        ),
        BulkTransactionItem(
          date: date,
          description: 'Salário',
          type: 'income',
          amount: 300000,
          accountId: accountId,
        ),
        BulkTransactionItem(
          date: date,
          description: 'Reserva',
          type: 'transfer',
          amount: 10000,
          accountId: accountId,
          toAccountId: toAccountId,
        ),
      ]);

      expect(ids.length, 3);

      final txs = await repository.watchAllTransactions().first;
      expect(txs.length, 3);

      // expense (1 credit) + income (1 debit) + transfer (credit + debit)
      final entries = await db.select(db.entries).get();
      expect(entries.length, 4);

      final checkingBal = await db.accountsDao
          .watchAccountBalance(accountId)
          .first;
      final savingsBal = await db.accountsDao
          .watchAccountBalance(toAccountId)
          .first;
      expect(checkingBal, -5000 + 300000 - 10000);
      expect(savingsBal, 10000);
    },
  );

  test('createTransactionsBulk is all-or-nothing when one row fails', () async {
    final accountId = await insertAccount('Checking');

    await expectLater(
      repository.createTransactionsBulk([
        BulkTransactionItem(
          date: DateTime.now(),
          description: 'Linha válida',
          type: 'expense',
          amount: 5000,
          accountId: accountId,
        ),
        BulkTransactionItem(
          date: DateTime.now(),
          description: 'Linha inválida',
          type: 'expense',
          amount: 3000,
          // Conta inexistente — viola a FK de entries.account_id.
          accountId: const Uuid().v4(),
        ),
      ]),
      throwsA(anything),
    );

    final txs = await db.select(db.transactions).get();
    final entries = await db.select(db.entries).get();
    expect(txs, isEmpty);
    expect(entries, isEmpty);
  });

  test(
    'createTransactionsBulk increments shared entity useCount by N',
    () async {
      final accountId = await insertAccount('Checking');
      final entityId = const Uuid().v4();
      await db
          .into(db.entities)
          .insert(
            EntitiesCompanion.insert(
              id: entityId,
              name: 'Padaria',
              type: 'payee',
            ),
          );

      await repository.createTransactionsBulk([
        for (var i = 0; i < 3; i++)
          BulkTransactionItem(
            date: DateTime.now(),
            description: 'Compra $i',
            type: 'expense',
            amount: 1000,
            entityId: entityId,
            accountId: accountId,
          ),
      ]);

      final entity = await (db.select(
        db.entities,
      )..where((t) => t.id.equals(entityId))).getSingle();
      expect(entity.useCount, 3);
    },
  );

  test('createTransactionsBulk respects isCompleted flag (pendente)', () async {
    final accountId = await insertAccount('Checking');

    await repository.createTransactionsBulk([
      BulkTransactionItem(
        date: DateTime.now(),
        description: 'Conta pendente',
        type: 'expense',
        amount: 2000,
        accountId: accountId,
        isCompleted: false,
      ),
    ]);

    final tx = await (db.select(db.transactions)).getSingle();
    expect(tx.isCompleted, isFalse);
    expect(tx.isConfirmed, isTrue);
  });

  test('createTransactionsBulk persists a shared groupId', () async {
    final accountId = await insertAccount('Checking');
    const groupId = 'group-abc';

    await repository.createTransactionsBulk([
      for (var i = 0; i < 3; i++)
        BulkTransactionItem(
          date: DateTime.now(),
          description: 'Item $i',
          type: 'expense',
          amount: 1000 * (i + 1),
          accountId: accountId,
          groupId: groupId,
        ),
    ]);

    final txs = await db.select(db.transactions).get();
    expect(txs.length, 3);
    expect(txs.every((t) => t.groupId == groupId), isTrue);

    // groupId sobrevive à edição (update não deve limpá-lo).
    final target = txs.first;
    await repository.updateTransaction(
      id: target.id,
      date: target.date,
      description: 'Editado',
      type: 'expense',
      amount: 9999,
      accountId: accountId,
    );
    final reloaded = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(target.id))).getSingle();
    expect(reloaded.groupId, groupId);
    expect(reloaded.description, 'Editado');
  });

  test(
    'updateGroupedTransactions replaces members and recalculates balance',
    () async {
      final accountId = await insertAccount('Checking');
      const groupId = 'group-edit';

      await repository.createTransactionsBulk([
        for (var i = 0; i < 3; i++)
          BulkTransactionItem(
            date: DateTime.now(),
            description: 'Item $i',
            type: 'expense',
            amount: 1000,
            accountId: accountId,
            groupId: groupId,
          ),
      ]);
      // 3 despesas de 1000 = -3000
      expect(await db.accountsDao.watchAccountBalance(accountId).first, -3000);

      // Edita o bloco: agora 2 linhas com valores diferentes.
      await repository.updateGroupedTransactions(groupId, [
        BulkTransactionItem(
          date: DateTime.now(),
          description: 'Novo A',
          type: 'expense',
          amount: 2500,
          accountId: accountId,
          groupId: groupId,
        ),
        BulkTransactionItem(
          date: DateTime.now(),
          description: 'Novo B',
          type: 'expense',
          amount: 500,
          accountId: accountId,
          groupId: groupId,
        ),
      ]);

      final txs = await repository.watchAllTransactions().first;
      expect(txs.length, 2);
      expect(txs.every((t) => t.groupId == groupId), isTrue);
      expect(txs.map((t) => t.description).toSet(), {'Novo A', 'Novo B'});
      // Saldo recalculado: -(2500 + 500) = -3000 (mesma soma, membros novos).
      expect(await db.accountsDao.watchAccountBalance(accountId).first, -3000);

      // Nenhuma entry órfã dos membros antigos.
      final entries = await db.select(db.entries).get();
      expect(entries.length, 2);
    },
  );

  test('updateGroupedTransactions can ungroup (groupId null)', () async {
    final accountId = await insertAccount('Checking');
    const groupId = 'group-ungroup';
    await repository.createTransactionsBulk([
      for (var i = 0; i < 2; i++)
        BulkTransactionItem(
          date: DateTime.now(),
          description: 'Item $i',
          type: 'expense',
          amount: 1000,
          accountId: accountId,
          groupId: groupId,
        ),
    ]);

    // Salva as linhas sem groupId — desagrupando o bloco.
    await repository.updateGroupedTransactions(groupId, [
      for (var i = 0; i < 2; i++)
        BulkTransactionItem(
          date: DateTime.now(),
          description: 'Avulso $i',
          type: 'expense',
          amount: 1000,
          accountId: accountId,
        ),
    ]);

    final txs = await repository.watchAllTransactions().first;
    expect(txs.length, 2);
    expect(txs.every((t) => t.groupId == null), isTrue);
  });

  test('ungrouped bulk items keep groupId null', () async {
    final accountId = await insertAccount('Checking');
    await repository.createTransactionsBulk([
      BulkTransactionItem(
        date: DateTime.now(),
        description: 'Avulso',
        type: 'expense',
        amount: 1000,
        accountId: accountId,
      ),
    ]);
    final tx = await db.select(db.transactions).getSingle();
    expect(tx.groupId, isNull);
  });

  group('CreateTransactionsBulk usecase validation', () {
    test('rejects empty batch', () {
      final usecase = CreateTransactionsBulk(repository);
      expect(() => usecase([]), throwsArgumentError);
    });

    test('rejects transfer with same source and destination', () async {
      final usecase = CreateTransactionsBulk(repository);
      final accountId = await insertAccount('Checking');

      expect(
        () => usecase([
          BulkTransactionItem(
            date: DateTime.now(),
            description: 'Transferência',
            type: 'transfer',
            amount: 1000,
            accountId: accountId,
            toAccountId: accountId,
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects zero amount and empty description', () async {
      final usecase = CreateTransactionsBulk(repository);
      final accountId = await insertAccount('Checking');

      expect(
        () => usecase([
          BulkTransactionItem(
            date: DateTime.now(),
            description: 'Sem valor',
            type: 'expense',
            amount: 0,
            accountId: accountId,
          ),
        ]),
        throwsArgumentError,
      );

      expect(
        () => usecase([
          BulkTransactionItem(
            date: DateTime.now(),
            description: '   ',
            type: 'expense',
            amount: 1000,
            accountId: accountId,
          ),
        ]),
        throwsArgumentError,
      );
    });
  });
}
