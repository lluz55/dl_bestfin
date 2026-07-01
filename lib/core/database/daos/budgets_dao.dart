import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/budgets.dart';
import '../tables/transactions.dart';
import '../tables/entries.dart';

part 'budgets_dao.g.dart';

class BudgetWithSpending {
  final Budget budget;
  final int spent;

  const BudgetWithSpending({required this.budget, required this.spent});

  int get available => budget.amount + budget.rolloverAmount - spent;
  double get progress =>
      budget.amount == 0 ? 0 : spent / (budget.amount + budget.rolloverAmount);
}

@DriftAccessor(tables: [Budgets, Transactions, Entries])
class BudgetsDao extends DatabaseAccessor<AppDatabase> with _$BudgetsDaoMixin {
  BudgetsDao(super.db);

  // ── Reads ──────────────────────────────────────────────────────────────────

  Stream<List<Budget>> watchByPeriod(int year, int month) {
    return (select(budgets)
          ..where((b) => b.year.equals(year) & b.month.equals(month))
          ..orderBy([(b) => OrderingTerm.asc(b.createdAt)]))
        .watch();
  }

  Future<List<Budget>> getByPeriod(int year, int month) {
    return (select(
      budgets,
    )..where((b) => b.year.equals(year) & b.month.equals(month))).get();
  }

  Future<Budget?> getForCategory(String categoryId, int year, int month) {
    return (select(budgets)..where(
          (b) =>
              b.categoryId.equals(categoryId) &
              b.year.equals(year) &
              b.month.equals(month),
        ))
        .getSingleOrNull();
  }

  /// Calcula o total gasto em [categoryId] durante o período [year]/[month].
  Future<int> getSpentForCategory(
    String categoryId,
    int year,
    int month,
  ) async {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);

    final query = selectOnly(transactions)
      ..addColumns([entries.amount.sum()])
      ..join([
        innerJoin(entries, entries.transactionId.equalsExp(transactions.id)),
      ])
      ..where(
        transactions.categoryId.equals(categoryId) &
            transactions.type.equals('expense') &
            transactions.isConfirmed.equals(true) &
            transactions.date.isBiggerOrEqualValue(start) &
            transactions.date.isSmallerThanValue(end) &
            entries.type.equals('credit'),
      );

    final row = await query.getSingleOrNull();
    return row?.read(entries.amount.sum()) ?? 0;
  }

  /// Retorna todos os budgets do período com o valor gasto calculado.
  Future<List<BudgetWithSpending>> getBudgetsWithSpending(
    int year,
    int month,
  ) async {
    final periodBudgets = await getByPeriod(year, month);
    final result = <BudgetWithSpending>[];

    for (final budget in periodBudgets) {
      final spent = await getSpentForCategory(budget.categoryId, year, month);
      result.add(BudgetWithSpending(budget: budget, spent: spent));
    }

    return result;
  }

  Stream<List<BudgetWithSpending>> watchBudgetsWithSpending(
    int year,
    int month,
  ) {
    return watchByPeriod(year, month).asyncMap((budgetList) async {
      final result = <BudgetWithSpending>[];
      for (final budget in budgetList) {
        final spent = await getSpentForCategory(budget.categoryId, year, month);
        result.add(BudgetWithSpending(budget: budget, spent: spent));
      }
      return result;
    });
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<Budget> insertBudget({
    required String categoryId,
    required int year,
    required int month,
    required int amount,
    int rolloverAmount = 0,
  }) async {
    final id = const Uuid().v4();
    await into(budgets).insert(
      BudgetsCompanion.insert(
        id: id,
        categoryId: categoryId,
        year: year,
        month: month,
        amount: amount,
        rolloverAmount: Value(rolloverAmount),
      ),
    );
    return (select(budgets)..where((b) => b.id.equals(id))).getSingle();
  }

  Future<void> updateBudget(String id, int amount) {
    return (update(budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(amount: Value(amount), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> applyRollover(String budgetId, int rolloverAmount) {
    return (update(budgets)..where((b) => b.id.equals(budgetId))).write(
      BudgetsCompanion(
        rolloverAmount: Value(rolloverAmount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteBudget(String id) {
    return (delete(budgets)..where((b) => b.id.equals(id))).go();
  }
}
