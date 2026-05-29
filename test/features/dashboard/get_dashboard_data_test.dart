import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';
import 'package:bestfin/features/goals/data/repositories/goal_repository.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/dashboard/domain/usecases/get_dashboard_data.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository transactionRepository;
  late AccountRepository accountRepository;
  late GoalRepository goalRepository;
  late GetDashboardData getDashboardData;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    transactionRepository = TransactionRepositoryImpl(db);
    accountRepository = AccountRepositoryImpl(db);
    goalRepository = GoalRepositoryImpl(db);
    getDashboardData = GetDashboardData(
      transactionRepository: transactionRepository,
      accountRepository: accountRepository,
      goalRepository: goalRepository,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'GetDashboardData aggregates balances, categories, and recent transactions correctly',
    () async {
      final now = DateTime.now();

      // 1. Criar contas ativas e inativas
      final activeAccId = const Uuid().v4();
      final inactiveAccId = const Uuid().v4();

      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: activeAccId,
          name: 'Conta Corrente Ativa',
          type: 'checking',
        ),
      );

      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: inactiveAccId,
          name: 'Conta Arquivada',
          type: 'savings',
          isArchived: const Value(true),
        ),
      );

      // 2. Categorias de despesas já estão pré-semeadas pelo AppDatabase (cat_food, cat_transport, cat_leisure)

      // 3. Criar algumas transações do mês corrente
      // Receita: R$ 5.000,00
      await transactionRepository.createTransaction(
        date: now.subtract(const Duration(hours: 4)),
        description: 'Salário',
        type: 'income',
        amount: 500000,
        accountId: activeAccId,
      );

      // Despesa 1 (Alimentação): R$ 150,00
      await transactionRepository.createTransaction(
        date: now.subtract(const Duration(hours: 3)),
        description: 'Supermercado',
        type: 'expense',
        amount: 15000,
        categoryId: 'cat_food',
        accountId: activeAccId,
      );

      // Despesa 2 (Transporte): R$ 50,00
      await transactionRepository.createTransaction(
        date: now.subtract(const Duration(hours: 2)),
        description: 'Uber',
        type: 'expense',
        amount: 5000,
        categoryId: 'cat_transport',
        accountId: activeAccId,
      );

      // Despesa 3 (Lazer): R$ 30,00
      await transactionRepository.createTransaction(
        date: now.subtract(const Duration(hours: 1)),
        description: 'Cinema',
        type: 'expense',
        amount: 3000,
        categoryId: 'cat_leisure',
        accountId: activeAccId,
      );

      // Despesa 4 (Mês passado, não deve entrar nos agregados mensais): R$ 100,00
      final lastMonth = DateTime(now.year, now.month - 1, 15);
      await transactionRepository.createTransaction(
        date: lastMonth,
        description: 'Aluguel Mês Passado',
        type: 'expense',
        amount: 10000,
        categoryId: 'cat_food',
        accountId: activeAccId,
      );

      // Obter dados agregados via stream
      final dashboardData = await getDashboardData().first;

      // Verificar Saldo Consolidado:
      // Salário (+5.000,00) - Supermercado (-150,00) - Uber (-50,00) - Cinema (-30,00) - Aluguel Mês Passado (-100,00) = R$ 4.670,00
      // Em centavos: 467000
      expect(dashboardData.totalBalance, 467000);

      // Verificar Receita do mês corrente: R$ 5.000,00
      expect(dashboardData.monthlyIncome, 500000);

      // Verificar Despesas do mês corrente (exclui mês passado): R$ 150,00 + R$ 50,00 + R$ 30,00 = R$ 230,00
      expect(dashboardData.monthlyExpense, 23000);

      // Verificar categoria com maior gasto (Alimentação - R$ 150,00):
      expect(dashboardData.categoryExpenses.length, 3);
      expect(dashboardData.categoryExpenses.first.categoryName, 'Alimentação');
      expect(dashboardData.categoryExpenses.first.amountInCents, 15000);
      // Proporção de Alimentação nos gastos totais do mês: 150 / 230 ~= 65.2%
      expect(
        dashboardData.categoryExpenses.first.percentage,
        closeTo(15000 / 23000, 0.001),
      );

      // Verificar as transações recentes (devem conter as 5 transações em ordem decrescente de data):
      expect(dashboardData.recentTransactions.length, 5);
      expect(
        dashboardData.recentTransactions.first.description,
        'Cinema',
      ); // A mais recente
    },
  );
}
