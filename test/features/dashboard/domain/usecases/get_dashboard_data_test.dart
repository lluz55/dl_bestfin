import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';
import 'package:bestfin/features/goals/data/repositories/goal_repository.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/dashboard/domain/usecases/get_dashboard_data.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

Future<void> _insertPendingTx(
  AppDatabase db,
  String accId, {
  required DateTime date,
  required String description,
  required String type,
  required int amount,
}) async {
  final txId = _uuid.v4();
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: txId,
          date: date,
          description: description,
          type: type,
          isCompleted: const Value(false),
        ),
      );
  await db
      .into(db.entries)
      .insert(
        EntriesCompanion.insert(
          id: _uuid.v4(),
          transactionId: txId,
          accountId: accId,
          amount: amount,
          type: type == 'income' ? 'debit' : 'credit',
        ),
      );
}

void main() {
  late AppDatabase db;
  late TransactionRepository txRepo;
  late AccountRepository accRepo;
  late GoalRepository goalRepo;
  late GetDashboardData useCase;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    txRepo = TransactionRepositoryImpl(db);
    accRepo = AccountRepositoryImpl(db);
    goalRepo = GoalRepositoryImpl(db);
    useCase = GetDashboardData(
      transactionRepository: txRepo,
      accountRepository: accRepo,
      goalRepository: goalRepo,
    );
  });

  tearDown(() async => db.close());

  group('freeToSpendAmount', () {
    test(
      'reflete liquidBalance descontado de despesas pendentes (partida dobrada)',
      () async {
        final now = DateTime.now();
        final accId = _uuid.v4();

        await db.accountsDao.insertAccount(
          AccountsCompanion.insert(id: accId, name: 'CC', type: 'checking'),
        );
        // Receita de R$ 5.000 (completa)
        await txRepo.createTransaction(
          date: now,
          description: 'Salário',
          type: 'income',
          amount: 500000,
          accountId: accId,
        );
        // Despesa pendente: R$ 500 — entry já debita o saldo da conta
        await _insertPendingTx(
          db,
          accId,
          date: now,
          description: 'Aluguel',
          type: 'expense',
          amount: 50000,
        );

        final data = await useCase().first;

        // liquidBalance = 500000 - 50000 = 450000 (entry criada mesmo pending)
        // freeToSpend = liquidBalance(450000) - goalTarget(0) = 450000
        expect(data.freeToSpendAmount, 450000);
        expect(data.freeToSpendPercentage, closeTo(1.0, 0.001));
      },
    );

    test(
      'transações pendentes de outros meses ainda afetam o liquidBalance',
      () async {
        final now = DateTime.now();
        final accId = _uuid.v4();

        await db.accountsDao.insertAccount(
          AccountsCompanion.insert(id: accId, name: 'CC', type: 'checking'),
        );
        await txRepo.createTransaction(
          date: now,
          description: 'Salário',
          type: 'income',
          amount: 300000,
          accountId: accId,
        );
        // Despesa pendente do mês passado — afeta saldo pois entry existe
        final lastMonth = DateTime(now.year, now.month - 1, 10);
        await _insertPendingTx(
          db,
          accId,
          date: lastMonth,
          description: 'Conta antiga',
          type: 'expense',
          amount: 100000,
        );

        final data = await useCase().first;

        // liquidBalance = 300000 - 100000 = 200000
        // freeToSpend = 200000 - goalTarget(0) = 200000
        expect(data.freeToSpendAmount, 200000);
      },
    );

    test('desconta meta de poupança mensal de objetivos com prazo', () async {
      final now = DateTime.now();
      final accId = _uuid.v4();

      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(id: accId, name: 'CC', type: 'checking'),
      );
      await txRepo.createTransaction(
        date: now,
        description: 'Salário',
        type: 'income',
        amount: 600000,
        accountId: accId,
      );
      // Meta: R$ 12.000 em 12 meses → R$ 1.000/mês
      final targetDate = DateTime(now.year + 1, now.month, now.day);
      await goalRepo.createGoal(
        name: 'Reserva',
        targetAmountInCents: 1200000,
        targetDate: targetDate,
      );

      final data = await useCase().first;

      // monthlyTarget = ceil(1200000 / 12) = 100000
      // freeToSpend = liquidBalance(600000) - goalTarget(100000) = 500000
      expect(data.freeToSpendAmount, 500000);
    });

    test('percentage zerado quando não há contas líquidas', () async {
      final data = await useCase().first;
      expect(data.freeToSpendPercentage, 0.0);
    });

    test('percentage clampado ao intervalo [0.0, 1.0]', () async {
      final now = DateTime.now();
      final accId = _uuid.v4();

      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(id: accId, name: 'CC', type: 'checking'),
      );
      await txRepo.createTransaction(
        date: now,
        description: 'Receita',
        type: 'income',
        amount: 100000,
        accountId: accId,
      );

      final data = await useCase().first;

      expect(data.freeToSpendPercentage, lessThanOrEqualTo(1.0));
      expect(data.freeToSpendPercentage, greaterThanOrEqualTo(0.0));
    });

    test('contas de investimento não entram no saldo líquido', () async {
      final now = DateTime.now();
      final investId = _uuid.v4();
      final checkId = _uuid.v4();

      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: investId,
          name: 'Investimentos',
          type: 'investment',
        ),
      );
      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(id: checkId, name: 'CC', type: 'checking'),
      );

      // Receita na conta corrente: R$ 200
      await txRepo.createTransaction(
        date: now,
        description: 'Salário',
        type: 'income',
        amount: 20000,
        accountId: checkId,
      );
      // Receita na conta de investimento: R$ 500 (não deve entrar no líquido)
      await txRepo.createTransaction(
        date: now,
        description: 'Rendimento',
        type: 'income',
        amount: 50000,
        accountId: investId,
      );

      final data = await useCase().first;

      // totalBalance = 20000 + 50000 = 70000, liquidBalance = 20000 (só checking)
      expect(data.totalBalance, 70000);
      // freeToSpend = liquidBalance(20000) - goalTarget(0) = 20000
      expect(data.freeToSpendAmount, 20000);
    });
  });

  group('upcomingTransactions', () {
    test(
      'retorna transações futuras não completadas, ordenadas por data',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final accId = _uuid.v4();

        await db.accountsDao.insertAccount(
          AccountsCompanion.insert(id: accId, name: 'CC', type: 'checking'),
        );

        // Futura — 5 dias
        await _insertPendingTx(
          db,
          accId,
          date: today.add(const Duration(days: 5)),
          description: 'Conta de Luz',
          type: 'expense',
          amount: 20000,
        );
        // Futura — 2 dias (deve aparecer primeiro)
        await _insertPendingTx(
          db,
          accId,
          date: today.add(const Duration(days: 2)),
          description: 'Streaming',
          type: 'expense',
          amount: 3990,
        );
        // Passada — NÃO deve aparecer
        await _insertPendingTx(
          db,
          accId,
          date: today.subtract(const Duration(days: 3)),
          description: 'Conta Velha',
          type: 'expense',
          amount: 5000,
        );
        // Futura mas já COMPLETADA — NÃO deve aparecer
        await txRepo.createTransaction(
          date: today.add(const Duration(days: 1)),
          description: 'Já pago',
          type: 'expense',
          amount: 1000,
          accountId: accId,
        );

        final data = await useCase().first;

        expect(data.upcomingTransactions.length, 2);
        expect(data.upcomingTransactions.first.description, 'Streaming');
        expect(data.upcomingTransactions.last.description, 'Conta de Luz');
      },
    );

    test('limita a 3 próximas transações', () async {
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final accId = _uuid.v4();

      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(id: accId, name: 'CC', type: 'checking'),
      );

      for (int i = 1; i <= 5; i++) {
        await _insertPendingTx(
          db,
          accId,
          date: today.add(Duration(days: i)),
          description: 'Conta $i',
          type: 'expense',
          amount: 1000 * i,
        );
      }

      final data = await useCase().first;

      expect(data.upcomingTransactions.length, 3);
    });

    test('retorna lista vazia quando não há lançamentos futuros', () async {
      final data = await useCase().first;
      expect(data.upcomingTransactions, isEmpty);
    });
  });

  group('activeGoals', () {
    test('retorna os primeiros 3 objetivos ativos', () async {
      for (int i = 1; i <= 5; i++) {
        await goalRepo.createGoal(
          name: 'Meta $i',
          targetAmountInCents: 100000 * i,
        );
      }

      final data = await useCase().first;

      expect(data.activeGoals.length, 3);
    });

    test('retorna lista vazia quando não há objetivos ativos', () async {
      final data = await useCase().first;
      expect(data.activeGoals, isEmpty);
    });

    test('não retorna objetivos arquivados', () async {
      final id = await goalRepo.createGoal(
        name: 'Meta Ativa',
        targetAmountInCents: 50000,
      );
      await goalRepo.archiveGoal(id);

      final data = await useCase().first;

      expect(data.activeGoals, isEmpty);
    });
  });
}
