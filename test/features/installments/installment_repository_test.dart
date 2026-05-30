import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/installments/data/repositories/installment_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late InstallmentRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = InstallmentRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'createInstallmentPlan splits 10000 cents into 3 parcels correctly',
    () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
        ),
      );

      await repository.createInstallmentPlan(
        baseDate: DateTime(2024, 1, 15),
        description: 'TV',
        totalAmount: 10000, // R$ 100.00
        totalInstallments: 3,
        accountId: accountId,
      );

      final plans = await repository.watchInstallmentPlans().first;
      expect(plans.length, 1);

      final plan = plans.first;
      expect(plan.totalInstallments, 3);
      expect(plan.transactions.length, 3);

      // First two parcels = 3333, last = 3334
      expect(plan.transactions[0].amount, 3333);
      expect(plan.transactions[1].amount, 3333);
      expect(plan.transactions[2].amount, 3334);

      // Total must equal original amount
      final total = plan.transactions.fold(0, (s, t) => s + t.amount);
      expect(total, 10000);
    },
  );

  test(
    'createInstallmentPlan marks future transactions as not completed',
    () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
        ),
      );

      await repository.createInstallmentPlan(
        baseDate: DateTime(2024, 1, 15),
        description: 'Phone',
        totalAmount: 3000,
        totalInstallments: 2,
        accountId: accountId,
      );

      final plans = await repository.watchInstallmentPlans().first;
      final plan = plans.first;

      expect(plan.transactions[0].isCompleted, true);
      expect(plan.transactions[1].isCompleted, false);
    },
  );

  test(
    'cancelInstallmentPlan removes uncompleted transactions and plan',
    () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
        ),
      );

      await repository.createInstallmentPlan(
        baseDate: DateTime(2024, 1, 15),
        description: 'Tablet',
        totalAmount: 6000,
        totalInstallments: 3,
        accountId: accountId,
      );

      var plans = await repository.watchInstallmentPlans().first;
      final planId = plans.first.id;

      await repository.cancelInstallmentPlan(planId);

      plans = await repository.watchInstallmentPlans().first;
      expect(plans.isEmpty, true);

      final txs = await db.select(db.transactions).get();
      // Only the first (completed) transaction remains
      expect(txs.length, 1);
      expect(txs.first.installmentPlanId, null);
    },
  );

  test('watchInstallmentPlans computes paidInstallments correctly', () async {
    final accountId = const Uuid().v4();
    await db.accountsDao.insertAccount(
      AccountsCompanion.insert(
        id: accountId,
        name: 'Test Account',
        type: 'checking',
      ),
    );

    await repository.createInstallmentPlan(
      baseDate: DateTime(2024, 1, 15),
      description: 'Bike',
      totalAmount: 4000,
      totalInstallments: 2,
      accountId: accountId,
    );

    final plans = await repository.watchInstallmentPlans().first;
    expect(plans.first.paidInstallments, 1);
    expect(plans.first.isCompleted, false);
  });

  test(
    'createInstallmentPlan cleans duplicate suffixes and adds correct format',
    () async {
      final accountId = const Uuid().v4();
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Test Account',
          type: 'checking',
        ),
      );

      // Pass description with pre-existing suffix
      await repository.createInstallmentPlan(
        baseDate: DateTime(2024, 1, 15),
        description: 'Supermercado (1/10)',
        totalAmount: 10000,
        totalInstallments: 5,
        accountId: accountId,
      );

      final plans = await repository.watchInstallmentPlans().first;
      final plan = plans.first;

      // Verify first transaction description is Supermercado (1/5)
      expect(plan.transactions[0].description, 'Supermercado (1/5)');
      // Verify future transaction description is Supermercado (2/5)
      expect(plan.transactions[1].description, 'Supermercado (2/5)');
    },
  );
}
