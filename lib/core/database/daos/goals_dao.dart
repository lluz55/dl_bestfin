import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/goals.dart';
import 'package:bestfin/core/database/tables/goal_categories.dart';
import 'package:bestfin/core/database/tables/category_parents.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals, GoalCategories, CategoryParents])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db);

  // ── Reads ──────────────────────────────────────────────────────────────────

  Stream<List<Goal>> watchAllGoals() {
    return (select(
      goals,
    )..orderBy([(g) => OrderingTerm.desc(g.createdAt)])).watch();
  }

  Stream<List<Goal>> watchByStatus(String status) {
    return (select(goals)
          ..where((g) => g.status.equals(status))
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .watch();
  }

  Stream<Goal?> watchGoalById(String id) {
    return (select(goals)..where((g) => g.id.equals(id))).watchSingleOrNull();
  }

  Future<Goal?> getGoalById(String id) {
    return (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();
  }

  Future<List<Goal>> getAllActiveGoals() {
    return (select(goals)..where((g) => g.status.equals('active'))).get();
  }

  // ── GoalCategories ─────────────────────────────────────────────────────────

  Future<List<String>> getGoalCategoryIds(String goalId) async {
    final rows = await (select(
      goalCategories,
    )..where((g) => g.goalId.equals(goalId))).get();
    return rows.map((r) => r.categoryId).toList();
  }

  Future<void> setGoalCategories(
    String goalId,
    List<String> categoryIds,
  ) async {
    await (delete(goalCategories)..where((g) => g.goalId.equals(goalId))).go();
    if (categoryIds.isEmpty) return;
    await batch((b) {
      b.insertAll(
        goalCategories,
        categoryIds
            .map(
              (cId) => GoalCategoriesCompanion.insert(
                goalId: goalId,
                categoryId: cId,
              ),
            )
            .toList(),
      );
    });
  }

  /// Retorna todos os goals ativos que têm [categoryId] (ou qualquer pai dele)
  /// na sua lista de categorias absorvidas.
  Future<List<Goal>> getActiveGoalsForCategory(String categoryId) async {
    // Coleta o próprio categoryId + todos os seus pais
    final parentRows = await (select(
      categoryParents,
    )..where((r) => r.childCategoryId.equals(categoryId))).get();
    final candidateIds = {
      categoryId,
      ...parentRows.map((r) => r.parentCategoryId),
    };

    if (candidateIds.isEmpty) return [];

    final matched = await (select(
      goalCategories,
    )..where((g) => g.categoryId.isIn(candidateIds))).get();

    if (matched.isEmpty) return [];
    final goalIds = matched.map((m) => m.goalId).toSet().toList();

    return (select(
      goals,
    )..where((g) => g.id.isIn(goalIds) & g.status.equals('active'))).get();
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<int> insertGoal(GoalsCompanion goal) {
    return into(goals).insert(goal);
  }

  Future<bool> updateGoal(GoalsCompanion goal) {
    return update(goals).replace(goal);
  }

  Future<void> patchGoal(String id, GoalsCompanion companion) {
    return (update(goals)..where((g) => g.id.equals(id))).write(companion);
  }

  Future<void> addContribution(String id, int amountInCents) async {
    final goal = await getGoalById(id);
    if (goal == null) return;

    final newAmount = goal.currentAmount + amountInCents;
    await patchGoal(
      id,
      GoalsCompanion(
        currentAmount: Value(newAmount),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markCompleted(String id) {
    return patchGoal(
      id,
      GoalsCompanion(
        status: const Value('completed'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> archiveGoal(String id) {
    return patchGoal(
      id,
      GoalsCompanion(
        status: const Value('archived'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteGoal(String id) {
    return (delete(goals)..where((g) => g.id.equals(id))).go();
  }

  /// Reseta o currentAmount e atualiza o periodStartDate para o novo período.
  Future<void> resetPeriod(String id, DateTime newPeriodStart) {
    return patchGoal(
      id,
      GoalsCompanion(
        currentAmount: const Value(0),
        status: const Value('active'),
        periodStartDate: Value(newPeriodStart),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
