import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/budgets.dart';
import '../tables/transactions.dart';
import '../tables/entries.dart';

part 'budgets_dao.g.dart';

class CategorySpendingBreakdown {
  /// Gasto de transações já ocorridas (`isCompleted == true`).
  final int confirmed;

  /// Gasto "previsto" de transações futuras/pendentes (`isCompleted ==
  /// false`) dentro do mesmo período — não entra no gasto confirmado.
  final int pending;

  const CategorySpendingBreakdown({
    required this.confirmed,
    required this.pending,
  });

  int get total => confirmed + pending;
}

class BudgetWithSpending {
  final Budget budget;
  final int spent;
  final int pending;

  const BudgetWithSpending({
    required this.budget,
    required this.spent,
    this.pending = 0,
  });

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

  /// Retorna o gasto confirmado e o previsto de [categoryId] durante o
  /// período [year]/[month] num único round-trip.
  Future<CategorySpendingBreakdown> getSpendingBreakdownForCategory(
    String categoryId,
    int year,
    int month,
  ) async {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);

    final confirmedExpr = CustomExpression<int>(
      "SUM(CASE WHEN transactions.is_completed = 1 THEN entries.amount ELSE 0 END)",
    );
    final pendingExpr = CustomExpression<int>(
      "SUM(CASE WHEN transactions.is_completed = 0 THEN entries.amount ELSE 0 END)",
    );

    final query = selectOnly(transactions)
      ..addColumns([confirmedExpr, pendingExpr])
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
    return CategorySpendingBreakdown(
      confirmed: row?.read(confirmedExpr) ?? 0,
      pending: row?.read(pendingExpr) ?? 0,
    );
  }

  /// Calcula o total gasto (confirmado) em [categoryId] durante o período
  /// [year]/[month].
  Future<int> getSpentForCategory(
    String categoryId,
    int year,
    int month,
  ) async {
    final breakdown = await getSpendingBreakdownForCategory(
      categoryId,
      year,
      month,
    );
    return breakdown.confirmed;
  }

  /// Retorna todos os budgets do período com o valor gasto (confirmado e
  /// previsto) calculado.
  Future<List<BudgetWithSpending>> getBudgetsWithSpending(
    int year,
    int month,
  ) async {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);

    final confirmedExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN transactions.is_completed = 1 THEN entries.amount ELSE 0 END), 0)",
    );
    final pendingExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN transactions.is_completed = 0 THEN entries.amount ELSE 0 END), 0)",
    );

    final query = select(budgets).join([
      leftOuterJoin(
        transactions,
        transactions.categoryId.equalsExp(budgets.categoryId) &
            transactions.type.equals('expense') &
            transactions.isConfirmed.equals(true) &
            transactions.date.isBiggerOrEqualValue(start) &
            transactions.date.isSmallerThanValue(end),
      ),
      leftOuterJoin(
        entries,
        entries.transactionId.equalsExp(transactions.id) &
            entries.type.equals('credit'),
      ),
    ])
      ..where(budgets.year.equals(year) & budgets.month.equals(month))
      ..addColumns([confirmedExpr, pendingExpr]);

    query.groupBy([budgets.id]);

    final rows = await query.get();
    return rows.map((row) {
      final budget = row.readTable(budgets);
      final spent = row.read(confirmedExpr) ?? 0;
      final pending = row.read(pendingExpr) ?? 0;
      return BudgetWithSpending(
        budget: budget,
        spent: spent,
        pending: pending,
      );
    }).toList();
  }

  Stream<List<BudgetWithSpending>> watchBudgetsWithSpending(
    int year,
    int month,
  ) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);

    final confirmedExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN transactions.is_completed = 1 THEN entries.amount ELSE 0 END), 0)",
    );
    final pendingExpr = CustomExpression<int>(
      "COALESCE(SUM(CASE WHEN transactions.is_completed = 0 THEN entries.amount ELSE 0 END), 0)",
    );

    final query = select(budgets).join([
      leftOuterJoin(
        transactions,
        transactions.categoryId.equalsExp(budgets.categoryId) &
            transactions.type.equals('expense') &
            transactions.isConfirmed.equals(true) &
            transactions.date.isBiggerOrEqualValue(start) &
            transactions.date.isSmallerThanValue(end),
      ),
      leftOuterJoin(
        entries,
        entries.transactionId.equalsExp(transactions.id) &
            entries.type.equals('credit'),
      ),
    ])
      ..where(budgets.year.equals(year) & budgets.month.equals(month))
      ..addColumns([confirmedExpr, pendingExpr]);

    query.groupBy([budgets.id]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final budget = row.readTable(budgets);
        final spent = row.read(confirmedExpr) ?? 0;
        final pending = row.read(pendingExpr) ?? 0;
        return BudgetWithSpending(
          budget: budget,
          spent: spent,
          pending: pending,
        );
      }).toList();
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
    await _enqueueBudgetSync(id, 'insert');
    return (select(budgets)..where((b) => b.id.equals(id))).getSingle();
  }

  Future<void> updateBudget(String id, int amount) async {
    await (update(budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(amount: Value(amount), updatedAt: Value(DateTime.now())),
    );
    await _enqueueBudgetSync(id, 'update');
  }

  Future<void> applyRollover(String budgetId, int rolloverAmount) async {
    await (update(budgets)..where((b) => b.id.equals(budgetId))).write(
      BudgetsCompanion(
        rolloverAmount: Value(rolloverAmount),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _enqueueBudgetSync(budgetId, 'update');
  }

  Future<int> deleteBudget(String id) async {
    await _enqueueBudgetSync(id, 'delete');
    return (delete(budgets)..where((b) => b.id.equals(id))).go();
  }

  Future<void> _enqueueBudgetSync(String id, String operation) async {
    final budget = await (select(
      budgets,
    )..where((b) => b.id.equals(id))).getSingleOrNull();

    final payload = budget == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': budget.id,
            'category_id': budget.categoryId,
            'year': budget.year,
            'month': budget.month,
            'amount': budget.amount,
            'rollover_amount': budget.rolloverAmount,
            'created_at': budget.createdAt.toIso8601String(),
            'updated_at': budget.updatedAt.toIso8601String(),
          };

    await db.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'budget',
      entityId: id,
      payload: jsonEncode(payload),
    );
  }
}
