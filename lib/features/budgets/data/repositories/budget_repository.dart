import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/budgets/domain/models/budget_model.dart';

abstract class BudgetRepository {
  Stream<List<BudgetModel>> watchBudgetsForPeriod(int year, int month);
  Future<List<BudgetModel>> getBudgetsForPeriod(int year, int month);
  Future<void> createBudget({
    required String categoryId,
    required int year,
    required int month,
    required int amount,
  });
  Future<void> updateBudget(String id, int amount);
  Future<void> deleteBudget(String id);
  Future<void> applyRollover(int fromYear, int fromMonth);
}

class BudgetRepositoryImpl implements BudgetRepository {
  final AppDatabase _db;

  BudgetRepositoryImpl(this._db);

  Future<BudgetModel> _enrich(
    Budget budget, {
    required int spent,
    int pending = 0,
  }) async {
    String? name, color, icon;
    try {
      final cat = await _db.categoriesDao.getCategoryById(budget.categoryId);
      name = cat.name;
      color = cat.color;
      icon = cat.icon;
    } catch (_) {}
    return BudgetModel.fromDbWithSpending(
      budget,
      spent,
      pending: pending,
      categoryName: name,
      categoryColor: color,
      categoryIcon: icon,
    );
  }

  @override
  Stream<List<BudgetModel>> watchBudgetsForPeriod(int year, int month) {
    return _db.budgetsDao.watchBudgetsWithSpending(year, month).asyncMap((
      items,
    ) async {
      final result = <BudgetModel>[];
      for (final item in items) {
        result.add(
          await _enrich(item.budget, spent: item.spent, pending: item.pending),
        );
      }
      return result;
    });
  }

  @override
  Future<List<BudgetModel>> getBudgetsForPeriod(int year, int month) async {
    final items = await _db.budgetsDao.getBudgetsWithSpending(year, month);
    final result = <BudgetModel>[];
    for (final item in items) {
      result.add(
        await _enrich(item.budget, spent: item.spent, pending: item.pending),
      );
    }
    return result;
  }

  @override
  Future<void> createBudget({
    required String categoryId,
    required int year,
    required int month,
    required int amount,
  }) async {
    await _db.budgetsDao.insertBudget(
      categoryId: categoryId,
      year: year,
      month: month,
      amount: amount,
    );
  }

  @override
  Future<void> updateBudget(String id, int amount) {
    return _db.budgetsDao.updateBudget(id, amount);
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _db.budgetsDao.deleteBudget(id);
  }

  @override
  Future<void> applyRollover(int fromYear, int fromMonth) async {
    final items = await _db.budgetsDao.getBudgetsWithSpending(
      fromYear,
      fromMonth,
    );

    int toYear = fromYear;
    int toMonth = fromMonth + 1;
    if (toMonth > 12) {
      toMonth = 1;
      toYear++;
    }

    for (final item in items) {
      final available = item.available;
      if (available <= 0) continue;

      final existing = await _db.budgetsDao.getForCategory(
        item.budget.categoryId,
        toYear,
        toMonth,
      );

      if (existing != null) {
        final newRollover = existing.rolloverAmount + available;
        await _db.budgetsDao.applyRollover(existing.id, newRollover);
      } else {
        await _db.budgetsDao.insertBudget(
          categoryId: item.budget.categoryId,
          year: toYear,
          month: toMonth,
          amount: item.budget.amount,
          rolloverAmount: available,
        );
      }
    }
  }
}
