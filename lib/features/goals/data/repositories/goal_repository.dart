import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/core/database/daos/goals_dao.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';

abstract class GoalRepository {
  Stream<List<GoalModel>> watchAllGoals();
  Stream<List<GoalModel>> watchActiveGoals();
  Stream<List<GoalModel>> watchCompletedGoals();
  Stream<GoalModel?> watchGoalById(String id);
  Future<String> createGoal({
    required String name,
    String? description,
    required int targetAmountInCents,
    DateTime? targetDate,
    String? accountId,
    String? color,
    String? icon,
    GoalType type = GoalType.saving,
  });
  Future<void> updateGoal({
    required String id,
    required String name,
    String? description,
    required int targetAmountInCents,
    DateTime? targetDate,
    String? accountId,
    String? color,
    String? icon,
    GoalType? type,
  });
  Future<void> addContribution({
    required String goalId,
    required int amountInCents,
    required String fromAccountId,
    String? notes,
  });
  Future<void> archiveGoal(String id);
  Future<void> deleteGoal(String id);
}

class GoalRepositoryImpl implements GoalRepository {
  final db.AppDatabase _database;

  GoalRepositoryImpl(this._database);

  GoalsDao get _dao => _database.goalsDao;

  // ── Reads ──────────────────────────────────────────────────────────────────

  @override
  Stream<List<GoalModel>> watchAllGoals() {
    return _dao.watchAllGoals().map(
      (list) => list.map(GoalModel.fromDb).toList(),
    );
  }

  @override
  Stream<List<GoalModel>> watchActiveGoals() {
    return _dao
        .watchByStatus('active')
        .map((list) => list.map(GoalModel.fromDb).toList());
  }

  @override
  Stream<List<GoalModel>> watchCompletedGoals() {
    return _dao
        .watchByStatus('completed')
        .map((list) => list.map(GoalModel.fromDb).toList());
  }

  @override
  Stream<GoalModel?> watchGoalById(String id) {
    return _dao
        .watchGoalById(id)
        .map((g) => g != null ? GoalModel.fromDb(g) : null);
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  @override
  Future<String> createGoal({
    required String name,
    String? description,
    required int targetAmountInCents,
    DateTime? targetDate,
    String? accountId,
    String? color,
    String? icon,
    GoalType type = GoalType.saving,
  }) async {
    final id = const Uuid().v4();
    await _dao.insertGoal(
      db.GoalsCompanion.insert(
        id: id,
        name: name,
        description: Value(description),
        targetAmount: targetAmountInCents,
        targetDate: Value(targetDate),
        accountId: Value(accountId),
        color: Value(color),
        icon: Value(icon),
        type: Value(type.value),
        status: const Value('active'),
      ),
    );
    return id;
  }

  @override
  Future<void> updateGoal({
    required String id,
    required String name,
    String? description,
    required int targetAmountInCents,
    DateTime? targetDate,
    String? accountId,
    String? color,
    String? icon,
    GoalType? type,
  }) async {
    await _dao.patchGoal(
      id,
      db.GoalsCompanion(
        name: Value(name),
        description: Value(description),
        targetAmount: Value(targetAmountInCents),
        targetDate: Value(targetDate),
        accountId: Value(accountId),
        color: Value(color),
        icon: Value(icon),
        type: type != null ? Value(type.value) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> addContribution({
    required String goalId,
    required int amountInCents,
    required String fromAccountId,
    String? notes,
  }) async {
    // Busca o goal para obter a conta vinculada (destino da transferência)
    final goal = await _dao.getGoalById(goalId);
    if (goal == null) return;

    await _database.transaction(() async {
      // 1. Registra transferência real se a conta de destino do goal existe
      if (goal.accountId != null) {
        final txId = const Uuid().v4();
        await _database
            .into(_database.transactions)
            .insert(
              db.TransactionsCompanion.insert(
                id: txId,
                date: DateTime.now(),
                description: 'Contribuição: ${goal.name}',
                type: 'transfer',
                notes: Value(notes),
                isCompleted: const Value(true),
              ),
            );
        // Entry de saída (crédito na conta origem)
        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: txId,
                accountId: fromAccountId,
                amount: amountInCents,
                type: 'credit',
              ),
            );
        // Entry de entrada (débito na conta do objetivo)
        await _database
            .into(_database.entries)
            .insert(
              db.EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: txId,
                accountId: goal.accountId!,
                amount: amountInCents,
                type: 'debit',
              ),
            );
      }

      // 2. Atualiza currentAmount no goal
      await _dao.addContribution(goalId, amountInCents);

      // 3. Marca como completo se atingiu a meta
      final updated = await _dao.getGoalById(goalId);
      if (updated != null &&
          updated.currentAmount >= updated.targetAmount &&
          updated.status == 'active') {
        await _dao.markCompleted(goalId);
      }
    });
  }

  @override
  Future<void> archiveGoal(String id) => _dao.archiveGoal(id);

  @override
  Future<void> deleteGoal(String id) => _dao.deleteGoal(id);
}
