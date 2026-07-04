import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late String accountId;
  late String categoryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountId = const Uuid().v4();
    categoryId = const Uuid().v4();

    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(id: accountId, name: 'Checking', type: 'checking'),
    );
    await db.categoriesDao.insertCategory(
      CategoriesCompanion.insert(
        id: categoryId,
        name: 'Food',
        icon: 'restaurant',
        color: 'orange',
        type: 'expense',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'getSpendingBreakdownForCategory separates confirmed from pending spend',
    () async {
      final year = 2026;
      final month = 7;

      // Confirmed expense within the period.
      await db.transactionsDao.createTransaction(
        data: TransactionsCompanion.insert(
          id: const Uuid().v4(),
          date: DateTime(year, month, 5),
          description: 'Groceries',
          type: 'expense',
          categoryId: Value(categoryId),
        ),
        accountId: accountId,
        amount: 10000,
      );

      // Pending (future) expense within the same period.
      await db.transactionsDao.createTransaction(
        data: TransactionsCompanion.insert(
          id: const Uuid().v4(),
          date: DateTime(year, month, 20),
          description: 'Upcoming groceries',
          type: 'expense',
          categoryId: Value(categoryId),
          isCompleted: const Value(false),
        ),
        accountId: accountId,
        amount: 4000,
      );

      // Pending expense in a different month must not count.
      await db.transactionsDao.createTransaction(
        data: TransactionsCompanion.insert(
          id: const Uuid().v4(),
          date: DateTime(year, month + 1, 3),
          description: 'Next month groceries',
          type: 'expense',
          categoryId: Value(categoryId),
          isCompleted: const Value(false),
        ),
        accountId: accountId,
        amount: 9999,
      );

      final breakdown = await db.budgetsDao.getSpendingBreakdownForCategory(
        categoryId,
        year,
        month,
      );

      expect(breakdown.confirmed, 10000);
      expect(breakdown.pending, 4000);
      expect(breakdown.total, 14000);
      expect(await db.budgetsDao.getSpentForCategory(categoryId, year, month), 10000);
    },
  );

  test('getBudgetsWithSpending exposes both spent and pending', () async {
    final year = 2026;
    final month = 7;

    await db.budgetsDao.insertBudget(
      categoryId: categoryId,
      year: year,
      month: month,
      amount: 20000,
    );

    await db.transactionsDao.createTransaction(
      data: TransactionsCompanion.insert(
        id: const Uuid().v4(),
        date: DateTime(year, month, 5),
        description: 'Groceries',
        type: 'expense',
        categoryId: Value(categoryId),
      ),
      accountId: accountId,
      amount: 10000,
    );

    await db.transactionsDao.createTransaction(
      data: TransactionsCompanion.insert(
        id: const Uuid().v4(),
        date: DateTime(year, month, 20),
        description: 'Upcoming groceries',
        type: 'expense',
        categoryId: Value(categoryId),
        isCompleted: const Value(false),
      ),
      accountId: accountId,
      amount: 4000,
    );

    final results = await db.budgetsDao.getBudgetsWithSpending(year, month);
    final result = results.single;

    expect(result.spent, 10000);
    expect(result.pending, 4000);
    expect(result.available, 10000);
  });
}
