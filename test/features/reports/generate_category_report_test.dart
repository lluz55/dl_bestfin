import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_category_report.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repository;
  late GenerateCategoryReport useCase;
  late String accountId;
  late String categoryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepositoryImpl(db);
    useCase = GenerateCategoryReport(repository);

    accountId = const Uuid().v4();
    categoryId = const Uuid().v4();

    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(id: accountId, name: 'CC', type: 'checking'),
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

  tearDown(() async => db.close());

  test(
    'separates confirmed spend from pending (previsto) per category',
    () async {
      final start = DateTime(2026, 7, 1);
      final end = DateTime(2026, 7, 31, 23, 59, 59);

      await repository.createTransaction(
        date: DateTime(2026, 7, 5),
        description: 'Groceries',
        type: 'expense',
        amount: 10000,
        categoryId: categoryId,
        accountId: accountId,
      );

      final pendingId = const Uuid().v4();
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: pendingId,
              date: DateTime(2026, 7, 20),
              description: 'Upcoming groceries',
              type: 'expense',
              categoryId: Value(categoryId),
              isCompleted: const Value(false),
            ),
          );
      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: const Uuid().v4(),
              transactionId: pendingId,
              accountId: accountId,
              amount: 4000,
              type: 'credit',
            ),
          );

      final report = await useCase.call(startDate: start, endDate: end).first;

      expect(report.totalExpense, 10000);
      final item = report.items.single;
      expect(item.amountInCents, 10000);
      expect(item.pendingAmountInCents, 4000);
      expect(item.percentage, 1.0);
    },
  );
}
