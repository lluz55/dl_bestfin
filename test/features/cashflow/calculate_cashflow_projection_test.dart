import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/cashflow/domain/use_cases/calculate_cashflow_projection.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repository;
  late CalculateCashFlowProjection useCase;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepositoryImpl(db);
    useCase = CalculateCashFlowProjection(
      db: db,
      transactionRepository: repository,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'a pending transaction shifts the projection by its own amount, not double',
    () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Checking',
          type: 'checking',
        ),
      );

      // Confirmed income of 1000, already occurred.
      await db.transactionsDao.createTransaction(
        data: TransactionsCompanion.insert(
          id: const Uuid().v4(),
          date: DateTime.now(),
          description: 'Confirmed income',
          type: 'income',
        ),
        accountId: accountId,
        amount: 1000,
      );

      // Pending expense of 200, five days from now — already materialized as
      // a real Transaction+Entry row (like a recurring-generated instance).
      await db.transactionsDao.createTransaction(
        data: TransactionsCompanion.insert(
          id: const Uuid().v4(),
          date: DateTime.now().add(const Duration(days: 5)),
          description: 'Pending expense',
          type: 'expense',
          isCompleted: const Value(false),
        ),
        accountId: accountId,
        amount: 200,
      );

      final projection = await useCase.call(days: 90);

      // currentBalance must exclude the pending expense.
      expect(projection.currentBalance, 1000);

      // The pending expense should only be applied once across the window.
      expect(projection.projectedBalance90d, 800);
    },
  );
}
