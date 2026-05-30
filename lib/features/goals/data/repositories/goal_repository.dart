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
    bool isRecurring = false,
    GoalRecurrenceFrequency? recurrenceFrequency,
    List<String> categoryIds = const [],
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
    bool isRecurring = false,
    GoalRecurrenceFrequency? recurrenceFrequency,
    List<String> categoryIds = const [],
  });
  Future<void> addContribution({
    required String goalId,
    required int amountInCents,
    required String fromAccountId,
    String? notes,
  });
  Future<void> archiveGoal(String id);
  Future<void> deleteGoal(String id);
  Future<void> checkAndResetExpiredGoals();
}

class GoalRepositoryImpl implements GoalRepository {
  final db.AppDatabase _database;

  GoalRepositoryImpl(this._database);

  GoalsDao get _dao => _database.goalsDao;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<GoalModel> _toModel(db.Goal g) async {
    final catIds = await _dao.getGoalCategoryIds(g.id);
    return GoalModel.fromDb(g, categoryIds: catIds);
  }

  Future<List<GoalModel>> _toModels(List<db.Goal> list) async {
    final futures = list.map(_toModel);
    return Future.wait(futures);
  }

  // ── Reads ──────────────────────────────────────────────────────────────────

  @override
  Stream<List<GoalModel>> watchAllGoals() {
    return _dao.watchAllGoals().asyncMap(_toModels);
  }

  @override
  Stream<List<GoalModel>> watchActiveGoals() {
    return _dao.watchByStatus('active').asyncMap(_toModels);
  }

  @override
  Stream<List<GoalModel>> watchCompletedGoals() {
    return _dao.watchByStatus('completed').asyncMap(_toModels);
  }

  @override
  Stream<GoalModel?> watchGoalById(String id) {
    return _dao.watchGoalById(id).asyncMap(
      (g) => g != null ? _toModel(g) : null,
    );
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
    bool isRecurring = false,
    GoalRecurrenceFrequency? recurrenceFrequency,
    List<String> categoryIds = const [],
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
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
        isRecurring: Value(isRecurring),
        recurrenceFrequency: Value(recurrenceFrequency?.value),
        periodStartDate: isRecurring ? Value(now) : const Value.absent(),
      ),
    );
    if (categoryIds.isNotEmpty) {
      await _dao.setGoalCategories(id, categoryIds);
    }
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
    bool isRecurring = false,
    GoalRecurrenceFrequency? recurrenceFrequency,
    List<String> categoryIds = const [],
  }) async {
    final existing = await _dao.getGoalById(id);
    // Preserve periodStartDate if already set and goal remains recurring
    DateTime? periodStart;
    if (isRecurring) {
      periodStart = (existing?.isRecurring == true && existing?.periodStartDate != null)
          ? existing!.periodStartDate
          : DateTime.now();
    }

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
        isRecurring: Value(isRecurring),
        recurrenceFrequency: Value(recurrenceFrequency?.value),
        periodStartDate: Value(periodStart),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _dao.setGoalCategories(id, categoryIds);
  }

  @override
  Future<void> addContribution({
    required String goalId,
    required int amountInCents,
    required String fromAccountId,
    String? notes,
  }) async {
    final goal = await _dao.getGoalById(goalId);
    if (goal == null) return;

    await _database.transaction(() async {
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

      await _dao.addContribution(goalId, amountInCents);

      final updated = await _dao.getGoalById(goalId);
      if (updated != null &&
          updated.currentAmount >= updated.targetAmount &&
          updated.status == 'active' &&
          !updated.isRecurring) {
        await _dao.markCompleted(goalId);
      }
    });
  }

  @override
  Future<void> archiveGoal(String id) => _dao.archiveGoal(id);

  @override
  Future<void> deleteGoal(String id) => _dao.deleteGoal(id);

  /// Verifica todos os goals recorrentes ativos e reseta os que expiraram.
  @override
  Future<void> checkAndResetExpiredGoals() async {
    final activeGoals = await _dao.getAllActiveGoals();
    for (final g in activeGoals) {
      final model = GoalModel.fromDb(g);
      if (model.isPeriodExpired) {
        final next = model.nextPeriodStart ?? DateTime.now();
        await _dao.resetPeriod(g.id, next);
      }
    }
  }
}
