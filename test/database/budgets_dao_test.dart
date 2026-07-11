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
      AccountsCompanion.insert(
        id: accountId,
        name: 'Checking',
        type: 'checking',
      ),
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

  test('getBudgetsWithSpending exposes both spent and pending', () async {
    final year = 2026;
    final month = 7;

    await db.budgetsDao.insertBudget(
      name: 'Alimentação',
      year: year,
      month: month,
      amount: 20000,
      categoryIds: [categoryId],
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

  test('getCategoryIdsForBudget returns linked categories', () async {
    final year = 2026;
    final month = 7;

    final budget = await db.budgetsDao.insertBudget(
      name: 'Transporte',
      year: year,
      month: month,
      amount: 5000,
      categoryIds: [categoryId],
    );

    final catIds = await db.budgetsDao.getCategoryIdsForBudget(budget.id);
    expect(catIds, [categoryId]);
  });

  test('insertBudget with multiple categories', () async {
    final cat2Id = const Uuid().v4();
    await db.categoriesDao.insertCategory(
      CategoriesCompanion.insert(
        id: cat2Id,
        name: 'Transport',
        icon: 'directions_car',
        color: 'blue',
        type: 'expense',
      ),
    );

    final budget = await db.budgetsDao.insertBudget(
      name: 'Gastos Variados',
      year: 2026,
      month: 7,
      amount: 30000,
      categoryIds: [categoryId, cat2Id],
    );

    final catIds = await db.budgetsDao.getCategoryIdsForBudget(budget.id);
    expect(catIds.length, 2);
    expect(catIds, containsAll([categoryId, cat2Id]));
  });

  test('updateBudget replaces categories', () async {
    final cat2Id = const Uuid().v4();
    await db.categoriesDao.insertCategory(
      CategoriesCompanion.insert(
        id: cat2Id,
        name: 'Health',
        icon: 'local_hospital',
        color: 'red',
        type: 'expense',
      ),
    );

    final budget = await db.budgetsDao.insertBudget(
      name: 'Original',
      year: 2026,
      month: 7,
      amount: 10000,
      categoryIds: [categoryId],
    );

    await db.budgetsDao.updateBudget(
      budget.id,
      name: 'Atualizado',
      amount: 15000,
      categoryIds: [cat2Id],
    );

    final catIds = await db.budgetsDao.getCategoryIdsForBudget(budget.id);
    expect(catIds, [cat2Id]);
  });
}
