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

  test('transfer transaction creates entries correctly', () async {
    final transactionsDao = db.transactionsDao;
    final accountsDao = db.accountsDao;

    final account1Id = const Uuid().v4();
    final account2Id = const Uuid().v4();

    await accountsDao.insertAccount(
      AccountsCompanion.insert(id: account1Id, name: 'Acc 1', type: 'checking'),
    );
    await accountsDao.insertAccount(
      AccountsCompanion.insert(id: account2Id, name: 'Acc 2', type: 'savings'),
    );

    await transactionsDao.createTransaction(
      data: TransactionsCompanion.insert(
        id: const Uuid().v4(),
        date: DateTime.now(),
        description: 'Transfer',
        type: 'transfer',
      ),
      accountId: account1Id,
      toAccountId: account2Id,
      amount: 500,
    );

    final b1 = await accountsDao.watchAccountBalance(account1Id).first;
    final b2 = await accountsDao.watchAccountBalance(account2Id).first;

    expect(b1, -500); // credited (decreased)
    expect(b2, 500); // debited (increased)
  });
}
