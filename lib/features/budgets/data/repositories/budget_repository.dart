import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/budgets/domain/models/budget_model.dart';

abstract class BudgetRepository {
  Stream<List<BudgetModel>> watchBudgetsForPeriod(int year, int month);
  Future<List<BudgetModel>> getBudgetsForPeriod(int year, int month);
  Future<void> createBudget({
    required String name,
    required int year,
    required int month,
    required int amount,
    required List<String> categoryIds,
  });
  Future<void> updateBudget(
    String id, {
    required String name,
    required int amount,
    required List<String> categoryIds,
  });
  Future<void> deleteBudget(String id);
  Future<void> applyRollover(int fromYear, int fromMonth);
}

class BudgetRepositoryImpl implements BudgetRepository {
  final AppDatabase _db;

  BudgetRepositoryImpl(this._db);

  Future<List<CategoryInfo>> _enrichCategories(
    List<String> categoryIds, {
    Map<String, String>? parentIdByChild,
  }) async {
    final result = <CategoryInfo>[];
    for (final catId in categoryIds) {
      try {
        final cat = await _db.categoriesDao.getCategoryById(catId);
        String name = cat.name;
        final parentId = parentIdByChild?[cat.id];
        if (parentId != null) {
          final parent = await _db.categoriesDao.getCategoryById(parentId);
          name = '${parent.name}/${cat.name}';
        }
        result.add(CategoryInfo(
          id: catId,
          name: name,
          color: cat.color,
          icon: cat.icon,
        ));
      } catch (_) {
        // Categoria não encontrada — ignorar.
      }
    }
    return result;
  }

  /// childCategoryId → parentCategoryId (primeiro pai encontrado), usado para
  /// exibir o nome como "Pai/Filho" nos orçamentos.
  Future<Map<String, String>> _parentIdByChild() async {
    final rels = await _db.categoriesDao.getAllRelationships();
    return {for (final r in rels) r.childCategoryId: r.parentCategoryId};
  }

  Future<BudgetModel> _enrich(
    Budget budget, {
    required int spent,
    int pending = 0,
    required List<String> categoryIds,
    Map<String, String>? parentIdByChild,
  }) async {
    final categories = await _enrichCategories(
      categoryIds,
      parentIdByChild: parentIdByChild,
    );

    return BudgetModel.fromDbWithSpending(
      budget,
      spent,
      pending: pending,
      categoryIds: categoryIds,
      categories: categories,
    );
  }

  @override
  Stream<List<BudgetModel>> watchBudgetsForPeriod(int year, int month) {
    return _db.budgetsDao.watchBudgetsWithSpending(year, month).asyncMap((
      items,
    ) async {
      final parents = await _parentIdByChild();
      final result = <BudgetModel>[];
      for (final item in items) {
        final categoryIds = await _db.budgetsDao.getCategoryIdsForBudget(
          item.budget.id,
        );
        result.add(
          await _enrich(
            item.budget,
            spent: item.spent,
            pending: item.pending,
            categoryIds: categoryIds,
            parentIdByChild: parents,
          ),
        );
      }
      return result;
    });
  }

  @override
  Future<List<BudgetModel>> getBudgetsForPeriod(int year, int month) async {
    final items = await _db.budgetsDao.getBudgetsWithSpending(year, month);
    final parents = await _parentIdByChild();
    final result = <BudgetModel>[];
    for (final item in items) {
      final categoryIds = await _db.budgetsDao.getCategoryIdsForBudget(
        item.budget.id,
      );
      result.add(
        await _enrich(
          item.budget,
          spent: item.spent,
          pending: item.pending,
          categoryIds: categoryIds,
          parentIdByChild: parents,
        ),
      );
    }
    return result;
  }

  @override
  Future<void> createBudget({
    required String name,
    required int year,
    required int month,
    required int amount,
    required List<String> categoryIds,
  }) async {
    await _db.budgetsDao.insertBudget(
      name: name,
      year: year,
      month: month,
      amount: amount,
      categoryIds: categoryIds,
    );
  }

  @override
  Future<void> updateBudget(
    String id, {
    required String name,
    required int amount,
    required List<String> categoryIds,
  }) {
    return _db.budgetsDao.updateBudget(
      id,
      name: name,
      amount: amount,
      categoryIds: categoryIds,
    );
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

      // Buscar categorias do orçamento original.
      final categoryIds = await _db.budgetsDao.getCategoryIdsForBudget(
        item.budget.id,
      );

      // Verificar se já existe orçamento para alguna categoria no mês destino.
      bool created = false;
      for (final catId in categoryIds) {
        // Buscar orçamentos do mês destino que tenham esta categoria.
        final existingBudgets = await _db.budgetsDao.getByPeriod(toYear, toMonth);
        for (final existing in existingBudgets) {
          final existingCats = await _db.budgetsDao.getCategoryIdsForBudget(
            existing.id,
          );
          if (existingCats.contains(catId)) {
            // Orçamento já existe para esta categoria — adicionar rollover.
            final newRollover = existing.rolloverAmount + available;
            await _db.budgetsDao.applyRollover(existing.id, newRollover);
            created = true;
            break;
          }
        }
        if (created) break;
      }

      if (!created) {
        // Criar novo orçamento no mês destino com as mesmas categorias.
        await _db.budgetsDao.insertBudget(
          name: item.budget.name,
          year: toYear,
          month: toMonth,
          amount: item.budget.amount,
          categoryIds: categoryIds,
          rolloverAmount: available,
        );
      }
    }
  }
}
