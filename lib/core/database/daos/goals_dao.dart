import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/goals.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db);

  // ── Reads ──────────────────────────────────────────────────────────────────

  /// Stream de todos os objetivos ordenados por data de criação (mais recente primeiro).
  Stream<List<Goal>> watchAllGoals() {
    return (select(
      goals,
    )..orderBy([(g) => OrderingTerm.desc(g.createdAt)])).watch();
  }

  /// Stream de objetivos filtrados por [status].
  Stream<List<Goal>> watchByStatus(String status) {
    return (select(goals)
          ..where((g) => g.status.equals(status))
          ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
        .watch();
  }

  /// Stream reativo de um único objetivo pelo ID.
  Stream<Goal?> watchGoalById(String id) {
    return (select(goals)..where((g) => g.id.equals(id))).watchSingleOrNull();
  }

  /// Busca sincrônica de um objetivo pelo ID.
  Future<Goal?> getGoalById(String id) {
    return (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Insere um novo objetivo.
  Future<int> insertGoal(GoalsCompanion goal) {
    return into(goals).insert(goal);
  }

  /// Atualiza completamente um objetivo existente.
  Future<bool> updateGoal(GoalsCompanion goal) {
    return update(goals).replace(goal);
  }

  /// Atualiza apenas campos específicos de um objetivo.
  Future<void> patchGoal(String id, GoalsCompanion companion) {
    return (update(goals)..where((g) => g.id.equals(id))).write(companion);
  }

  /// Incrementa atomicamente o `currentAmount` de um objetivo.
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

  /// Muda o status de um objetivo para `completed`.
  Future<void> markCompleted(String id) {
    return patchGoal(
      id,
      GoalsCompanion(
        status: const Value('completed'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Muda o status de um objetivo para `archived`.
  Future<void> archiveGoal(String id) {
    return patchGoal(
      id,
      GoalsCompanion(
        status: const Value('archived'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Exclui um objetivo pelo ID.
  Future<int> deleteGoal(String id) {
    return (delete(goals)..where((g) => g.id.equals(id))).go();
  }
}
