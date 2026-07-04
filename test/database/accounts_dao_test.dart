import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('accounts can be created and retrieved', () async {
    final dao = db.accountsDao;
    final accountId = const Uuid().v4();

    await dao.insertAccount(
      AccountsCompanion.insert(
        id: accountId,
        name: 'Test Account',
        type: 'checking',
      ),
    );

    final account = await dao.getAccountById(accountId);
    expect(account.name, 'Test Account');
    expect(account.type, 'checking');
  });

  test('balance is calculated from entries', () async {
    final accountsDao = db.accountsDao;
    final transactionsDao = db.transactionsDao;
    final accountId = const Uuid().v4();

    await accountsDao.insertAccount(
      AccountsCompanion.insert(
        id: accountId,
        name: 'Balance Test Account',
        type: 'checking',
      ),
    );

    // Income of 1000
    await transactionsDao.createTransaction(
      data: TransactionsCompanion.insert(
        id: const Uuid().v4(),
        date: DateTime.now(),
        description: 'Income',
        type: 'income',
      ),
      accountId: accountId,
      amount: 1000,
    );

    // Expense of 300
    await transactionsDao.createTransaction(
      data: TransactionsCompanion.insert(
        id: const Uuid().v4(),
        date: DateTime.now(),
        description: 'Expense',
        type: 'expense',
      ),
      accountId: accountId,
      amount: 300,
    );

    final balanceStream = accountsDao.watchAccountBalance(accountId);
    final balance = await balanceStream.first;
    expect(
      balance,
      700,
    ); // 1000 debit (increases assets) - 300 credit (decreases assets)
  });

  test(
    'getConfirmedBalance excludes pending transactions, unlike getTotalBalance',
    () async {
      final accountsDao = db.accountsDao;
      final transactionsDao = db.transactionsDao;
      final accountId = const Uuid().v4();

      await accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Confirmed Balance Test Account',
          type: 'checking',
        ),
      );

      // Completed income of 1000
      await transactionsDao.createTransaction(
        data: TransactionsCompanion.insert(
          id: const Uuid().v4(),
          date: DateTime.now(),
          description: 'Confirmed income',
          type: 'income',
        ),
        accountId: accountId,
        amount: 1000,
      );

      // Pending (future) income of 500 — not yet completed
      await transactionsDao.createTransaction(
        data: TransactionsCompanion.insert(
          id: const Uuid().v4(),
          date: DateTime.now().add(const Duration(days: 5)),
          description: 'Pending income',
          type: 'income',
          isCompleted: const Value(false),
        ),
        accountId: accountId,
        amount: 500,
      );

      expect(await accountsDao.getTotalBalance(), 1500);
      expect(await accountsDao.getConfirmedBalance(), 1000);
    },
  );

  test('getConfirmedBalance returns 0 when there are no entries', () async {
    expect(await db.accountsDao.getConfirmedBalance(), 0);
  });
}
