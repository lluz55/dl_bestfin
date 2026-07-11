import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/budgets.dart';
import '../tables/budget_categories.dart';
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

@DriftAccessor(tables: [Budgets, BudgetCategories, Transactions, Entries])
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

  /// Retorna as categorias vinculadas a um orçamento.
  Future<List<String>> getCategoryIdsForBudget(String budgetId) async {
    final rows = await (select(budgetCategories)
          ..where((bc) => bc.budgetId.equals(budgetId)))
        .get();
    return rows.map((r) => r.categoryId).toList();
  }

  /// Retorna todos os orçamentos de um período com categorias e gasto.
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

    // Buscar orçamentos do período.
    final budgetRows = await (select(budgets)
          ..where((b) => b.year.equals(year) & b.month.equals(month))
          ..orderBy([(b) => OrderingTerm.asc(b.createdAt)]))
        .get();

    final results = <BudgetWithSpending>[];
    for (final budget in budgetRows) {
      // Buscar categorias deste orçamento.
      final catIds = await getCategoryIdsForBudget(budget.id);

      int confirmed = 0;
      int pending = 0;

      if (catIds.isNotEmpty) {
        // Calcular gasto para todas as categorias do orçamento.
        final query = selectOnly(transactions)
          ..addColumns([confirmedExpr, pendingExpr])
          ..join([
            innerJoin(entries, entries.transactionId.equalsExp(transactions.id)),
          ])
          ..where(
            transactions.categoryId.isIn(catIds) &
                transactions.type.equals('expense') &
                transactions.isConfirmed.equals(true) &
                transactions.date.isBiggerOrEqualValue(start) &
                transactions.date.isSmallerThanValue(end) &
                entries.type.equals('credit'),
          );

        final row = await query.getSingleOrNull();
        confirmed = row?.read(confirmedExpr) ?? 0;
        pending = row?.read(pendingExpr) ?? 0;
      }

      results.add(BudgetWithSpending(
        budget: budget,
        spent: confirmed,
        pending: pending,
      ));
    }

    return results;
  }

  Stream<List<BudgetWithSpending>> watchBudgetsWithSpending(
    int year,
    int month,
  ) {
    // Reatividade: assiste mudanças em budgets e recalcula gastos.
    return watchByPeriod(year, month).asyncMap(
      (_) => getBudgetsWithSpending(year, month),
    );
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<Budget> insertBudget({
    required String name,
    required int year,
    required int month,
    required int amount,
    required List<String> categoryIds,
    int rolloverAmount = 0,
  }) async {
    final id = const Uuid().v4();
    await into(budgets).insert(
      BudgetsCompanion.insert(
        id: id,
        name: name,
        year: year,
        month: month,
        amount: amount,
        rolloverAmount: Value(rolloverAmount),
      ),
    );

    // Inserir categorias na tabela pivô.
    if (categoryIds.isNotEmpty) {
      await batch((batch) {
        batch.insertAll(
          budgetCategories,
          categoryIds
              .map((catId) => BudgetCategoriesCompanion.insert(
                    budgetId: id,
                    categoryId: catId,
                  ))
              .toList(),
        );
      });
    }

    await _enqueueBudgetSync(id, 'insert');
    return (select(budgets)..where((b) => b.id.equals(id))).getSingle();
  }

  Future<void> updateBudget(
    String id, {
    required String name,
    required int amount,
    required List<String> categoryIds,
  }) async {
    await (update(budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(
        name: Value(name),
        amount: Value(amount),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Atualizar categorias: deletar antigas e inserir novas.
    await (delete(budgetCategories)
          ..where((bc) => bc.budgetId.equals(id)))
        .go();
    if (categoryIds.isNotEmpty) {
      await batch((batch) {
        batch.insertAll(
          budgetCategories,
          categoryIds
              .map((catId) => BudgetCategoriesCompanion.insert(
                    budgetId: id,
                    categoryId: catId,
                  ))
              .toList(),
        );
      });
    }

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
    // Cascade delete cuida de budget_categories.
    return (delete(budgets)..where((b) => b.id.equals(id))).go();
  }

  Future<void> _enqueueBudgetSync(String id, String operation) async {
    final budget = await (select(
      budgets,
    )..where((b) => b.id.equals(id))).getSingleOrNull();

    // Buscar category_ids para o payload de sync.
    final catIds = budget != null ? await getCategoryIdsForBudget(id) : <String>[];

    final payload = budget == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': budget.id,
            'name': budget.name,
            'category_ids': catIds,
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
