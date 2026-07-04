import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_monthly_report.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repository;
  late GenerateMonthlyReport useCase;
  late String accountId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepositoryImpl(db);
    useCase = GenerateMonthlyReport(repository);

    accountId = const Uuid().v4();
    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(id: accountId, name: 'CC', type: 'checking'),
    );
  });

  tearDown(() async => db.close());

  test(
    'current month bar exposes pendingIncome/pendingExpense separately from confirmed',
    () async {
      final now = DateTime.now();

      await repository.createTransaction(
        date: now,
        description: 'Salário',
        type: 'income',
        amount: 500000,
        accountId: accountId,
      );

      final pendingId = const Uuid().v4();
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: pendingId,
              date: now,
              description: 'Fatura futura',
              type: 'expense',
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
              amount: 30000,
              type: 'credit',
            ),
          );

      final report = await useCase.call(months: 1).first;
      final bar = report.bars.single;

      expect(bar.year, now.year);
      expect(bar.month, now.month);
      expect(bar.income, 500000);
      expect(bar.expense, 0);
      expect(bar.pendingExpense, 30000);
      expect(bar.pendingIncome, 0);
    },
  );
}
