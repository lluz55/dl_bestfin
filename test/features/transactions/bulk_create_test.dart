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
