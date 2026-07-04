import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
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

  test(
    'createTransaction handles expense correctly (double entry credit)',
    () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Checking',
          type: 'checking',
        ),
      );

      await repository.createTransaction(
        date: DateTime.now(),
        description: 'Supermarket',
        type: 'expense',
        amount: 15000, // R$ 150.00
        accountId: accountId,
      );

      // Verify balance is decreased (credit increases liabilities/decreases assets, checking is asset)
      final balance = await db.accountsDao.watchAccountBalance(accountId).first;
      expect(balance, -15000);

      // Verify transaction exists
      final txs = await repository.watchAllTransactions().first;
      expect(txs.length, 1);
      expect(txs.first.description, 'Supermarket');
      expect(txs.first.type, TransactionType.expense);
      expect(txs.first.amount, 15000);
      expect(txs.first.accountId, accountId);
    },
  );

  test(
    'createTransaction handles income correctly (double entry debit)',
    () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Savings',
          type: 'savings',
        ),
      );

      await repository.createTransaction(
        date: DateTime.now(),
        description: 'Salary',
        type: 'income',
        amount: 500000, // R$ 5,000.00
        accountId: accountId,
      );

      // Verify balance is increased (debit increases assets)
      final balance = await db.accountsDao.watchAccountBalance(accountId).first;
      expect(balance, 500000);

      // Verify transaction exists
      final txs = await repository.watchAllTransactions().first;
      expect(txs.length, 1);
      expect(txs.first.description, 'Salary');
      expect(txs.first.type, TransactionType.income);
      expect(txs.first.amount, 500000);
    },
  );

  test(
    'createTransaction handles transfer correctly (credit source, debit destination)',
    () async {
      final acc1 = const Uuid().v4();
      final acc2 = const Uuid().v4();

      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(id: acc1, name: 'Wallet', type: 'wallet'),
      );
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: acc2,
          name: 'Investment',
          type: 'investment',
        ),
      );

      await repository.createTransaction(
        date: DateTime.now(),
        description: 'Invest R\$ 100',
        type: 'transfer',
        amount: 10000, // R$ 100.00
        accountId: acc1,
        toAccountId: acc2,
      );

      final walletBal = await db.accountsDao.watchAccountBalance(acc1).first;
      final investBal = await db.accountsDao.watchAccountBalance(acc2).first;

      expect(walletBal, -10000); // Credited
      expect(investBal, 10000); // Debited

      final txs = await repository.watchAllTransactions().first;
      expect(txs.length, 1);
      expect(txs.first.type, TransactionType.transfer);
      expect(txs.first.amount, 10000);
      expect(txs.first.fromAccountId, acc1);
      expect(txs.first.toAccountId, acc2);
    },
  );

  test('updateTransaction modifies entries and header correctly', () async {
    final acc = const Uuid().v4();
    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(id: acc, name: 'Wallet', type: 'wallet'),
    );

    await repository.createTransaction(
      date: DateTime.now(),
      description: 'Coffee',
      type: 'expense',
      amount: 800,
      accountId: acc,
    );

    final originalTxs = await repository.watchAllTransactions().first;
    final txId = originalTxs.first.id;

    await repository.updateTransaction(
      id: txId,
      date: DateTime.now(),
      description: 'Fancy Coffee',
      type: 'expense',
      amount: 1200,
      accountId: acc,
    );

    final walletBal = await db.accountsDao.watchAccountBalance(acc).first;
    expect(walletBal, -1200);

    final txs = await repository.watchAllTransactions().first;
    expect(txs.first.description, 'Fancy Coffee');
    expect(txs.first.amount, 1200);
  });

  test('deleteTransaction cleans up header and entries', () async {
    final acc = const Uuid().v4();
    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(id: acc, name: 'Wallet', type: 'wallet'),
    );

    await repository.createTransaction(
      date: DateTime.now(),
      description: 'Dinner',
      type: 'expense',
      amount: 8000,
      accountId: acc,
    );

    final originalTxs = await repository.watchAllTransactions().first;
    final txId = originalTxs.first.id;

    await repository.deleteTransaction(txId);

    final walletBal = await db.accountsDao.watchAccountBalance(acc).first;
    expect(walletBal, 0);

    final txs = await repository.watchAllTransactions().first;
    expect(txs.isEmpty, true);
  });

  test('getRecentDescriptions filters by type and matches query', () async {
    final acc = const Uuid().v4();
    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(id: acc, name: 'Wallet', type: 'wallet'),
    );

    // Expense
    await repository.createTransaction(
      date: DateTime.now(),
      description: 'Supermarket',
      type: 'expense',
      amount: 100,
      accountId: acc,
    );

    // Income
    await repository.createTransaction(
      date: DateTime.now(),
      description: 'Salary',
      type: 'income',
      amount: 1000,
      accountId: acc,
    );

    // Transfer
    await repository.createTransaction(
      date: DateTime.now(),
      description: 'Savings Transfer',
      type: 'transfer',
      amount: 500,
      accountId: acc,
      toAccountId: acc,
    );

    // Test query only
    final results1 = await repository.getRecentDescriptions(query: 'Super');
    expect(results1, ['Supermarket']);

    // Test type filtering
    final results2 = await repository.getRecentDescriptions(type: 'expense');
    expect(results2, ['Supermarket']);
    expect(results2.contains('Salary'), false);
    expect(results2.contains('Savings Transfer'), false);

    final results3 = await repository.getRecentDescriptions(type: 'transfer');
    expect(results3, ['Savings Transfer']);

    final results4 = await repository.getRecentDescriptions(type: 'income');
    expect(results4, ['Salary']);
  });

  test('markAsPaid completes a pending transaction', () async {
    final accountId = const Uuid().v4();
    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        id: accountId,
        name: 'Test Checking',
        type: 'checking',
      ),
    );

    final txId = await repository.createTransaction(
      date: DateTime.now().add(const Duration(days: 3)),
      description: 'Future installment',
      type: 'expense',
      amount: 5000,
      accountId: accountId,
    );

    // Simulate a recurring-generated instance not yet due (isCompleted=false).
    await (db.update(
      db.transactions,
    )..where((t) => t.id.equals(txId))).write(
      const TransactionsCompanion(isCompleted: Value(false)),
    );

    final pendingTxs = await repository.watchAllTransactions().first;
    expect(pendingTxs.single.isPending, isTrue);

    await repository.markAsPaid(txId);

    final updatedTxs = await repository.watchAllTransactions().first;
    expect(updatedTxs.single.isPending, isFalse);
    expect(updatedTxs.single.isConfirmed, isTrue);
  });
}
