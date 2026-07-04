import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
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
    if (categoryIds.isNotEmpty) {
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
    await _enqueueGoalSync(goalId, 'update');
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

  Future<int> insertGoal(GoalsCompanion goal) async {
    final res = await into(goals).insert(goal);
    await _enqueueGoalSync(goal.id.value, 'insert');
    return res;
  }

  Future<bool> updateGoal(GoalsCompanion goal) async {
    final res = await update(goals).replace(goal);
    await _enqueueGoalSync(goal.id.value, 'update');
    return res;
  }

  Future<void> patchGoal(String id, GoalsCompanion companion) async {
    await (update(goals)..where((g) => g.id.equals(id))).write(companion);
    await _enqueueGoalSync(id, 'update');
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

  Future<int> deleteGoal(String id) async {
    await _enqueueGoalSync(id, 'delete');
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

  Future<void> _enqueueGoalSync(String id, String operation) async {
    final goal = await getGoalById(id);
    final categoryIds = await getGoalCategoryIds(id);

    final payload = goal == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': goal.id,
            'name': goal.name,
            'description': goal.description,
            'target_amount': goal.targetAmount,
            'current_amount': goal.currentAmount,
            'target_date': goal.targetDate?.toIso8601String(),
            'account_id': goal.accountId,
            'color': goal.color,
            'icon': goal.icon,
            'type': goal.type,
            'status': goal.status,
            'is_recurring': goal.isRecurring,
            'recurrence_frequency': goal.recurrenceFrequency,
            'period_start_date': goal.periodStartDate?.toIso8601String(),
            'created_at': goal.createdAt.toIso8601String(),
            'updated_at': goal.updatedAt.toIso8601String(),
            'category_ids': categoryIds,
          };

    await db.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'goal',
      entityId: id,
      payload: jsonEncode(payload),
    );
  }
}
