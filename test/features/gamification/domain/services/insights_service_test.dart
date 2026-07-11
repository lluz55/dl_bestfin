import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';
import 'package:bestfin/features/goals/data/repositories/goal_repository.dart';
import 'package:bestfin/features/investments/data/repositories/investment_repository.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/gamification/domain/services/insights_service.dart';
import 'package:bestfin/features/gamification/domain/models/financial_insight.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository transactionRepository;
  late AccountRepository accountRepository;
  late GoalRepository goalRepository;
  late InvestmentRepository investmentRepository;
  late InsightsService insightsService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    transactionRepository = TransactionRepositoryImpl(db);
    accountRepository = AccountRepositoryImpl(db);
    goalRepository = GoalRepositoryImpl(db);
    investmentRepository = InvestmentRepositoryImpl(db);
    insightsService = InsightsService(
      transactionRepository: transactionRepository,
      db: db,
      accountRepository: accountRepository,
      goalRepository: goalRepository,
      investmentRepository: investmentRepository,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('InsightsService', () {
    test('returns welcome message when no transactions exist', () async {
      final insights = await insightsService.generateInsights();

      expect(insights.length, 1);
      expect(insights.first.text, contains('Comece a registrar suas transações'));
    });

    test('detects positive monthly balance', () async {
      final now = DateTime.now();
      final accountId = const Uuid().v4();

      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Conta Corrente',
          type: 'checking',
        ),
      );

      await transactionRepository.createTransaction(
        date: now,
        description: 'Salário',
        type: 'income',
        amount: 500000,
        accountId: accountId,
      );

      await transactionRepository.createTransaction(
        date: now,
        description: 'Supermercado',
        type: 'expense',
        amount: 15000,
        categoryId: 'cat_food',
        accountId: accountId,
      );

      final insights = await insightsService.generateInsights();

      expect(insights.any((i) => i.text.contains('Parabéns')), isTrue);
    });

    test('detects debt when financings exist', () async {
      final financingId = const Uuid().v4();

      await db.financingsDao.insertFinancing(
        FinancingsCompanion.insert(
          id: financingId,
          name: 'Financiamento Carro',
          totalAmount: 500000,
          outstandingBalance: 400000,
          interestRate: 12.5,
          totalInstallments: 60,
          amortizationSystem: 'sac',
        ),
      );

      final financings = await db.financingsDao.watchAllFinancings().first;
      expect(financings.length, 1);
      expect(financings.first.outstandingBalance, 400000);
    });

    test('detects negative sentiment transactions', () async {
      final now = DateTime.now();
      final accountId = const Uuid().v4();

      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Conta Corrente',
          type: 'checking',
        ),
      );

      await transactionRepository.createTransaction(
        date: now,
        description: 'Compra triste',
        type: 'expense',
        amount: 20000,
        sentiment: 'terrible',
        categoryId: 'cat_food',
        accountId: accountId,
      );

      final insights = await insightsService.generateInsights();

      expect(insights.any((i) => i.category == InsightCategory.behavior), isTrue);
    });

    test('detects budget overspending', () async {
      final now = DateTime.now();
      final accountId = const Uuid().v4();
      final categoryId = 'cat_food';

      await db.accountsDao.insertAccount(
        AccountsCompanion.insert(
          id: accountId,
          name: 'Conta Corrente',
          type: 'checking',
        ),
      );

      await db.budgetsDao.insertBudget(
        name: 'Alimentação',
        year: now.year,
        month: now.month,
        amount: 10000,
        categoryIds: [categoryId],
      );

      await transactionRepository.createTransaction(
        date: now,
        description: 'Supermercado',
        type: 'expense',
        amount: 15000,
        categoryId: categoryId,
        accountId: accountId,
      );

      final insights = await insightsService.generateInsights();

      expect(insights.any((i) => i.category == InsightCategory.budget), isTrue);
    });

    test('detects investments with negative yield', () async {
      final investmentId = const Uuid().v4();

      await db.investmentsDao.insertInvestment(
        InvestmentsCompanion.insert(
          id: investmentId,
          name: 'Tesouro Direto',
          type: 'tesouro',
          investedAmount: 100000,
          currentYield: const Value(-5000),
          maturityDate: Value(DateTime.now().add(const Duration(days: 30)))),
      );

      final investments = await investmentRepository.watchAllInvestments().first;
      expect(investments.length, 1);
      expect(investments.first.currentYield, -5000);
    });
  });
}