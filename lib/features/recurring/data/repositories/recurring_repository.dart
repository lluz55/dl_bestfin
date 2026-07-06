import 'dart:async';

import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/core/database/daos/recurring_rules_dao.dart';
import 'package:bestfin/core/notifications/reminder_scheduler.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

abstract class RecurringRepository {
  Stream<List<RecurringRuleModel>> watchByStatus(RecurringStatus status);
  Stream<List<RecurringRuleModel>> watchAll();
  Future<void> createRule({
    required String baseTransactionId,
    required RecurringFrequency frequency,
    required int interval,
    required DateTime startDate,
    DateTime? endDate,
    required bool autoConfirm,
  });
  Future<void> pauseRule(String id);
  Future<void> resumeRule(String id);
  Future<void> deleteRule(String id);
  Future<void> generatePendingTransactions({int daysAhead = 30});
}

class RecurringRepositoryImpl implements RecurringRepository {
  final db.AppDatabase _database;

  RecurringRepositoryImpl(this._database);

  /// Exposed for access from form screens if needed.
  db.AppDatabase get database => _database;

  RecurringRulesDao get _dao => _database.recurringRulesDao;

  @override
  Stream<List<RecurringRuleModel>> watchByStatus(RecurringStatus status) {
    return _dao.watchByStatus(status.name).asyncMap(_enrichRules);
  }

  @override
  Stream<List<RecurringRuleModel>> watchAll() {
    return _dao.watchAll().asyncMap(_enrichRules);
  }

  @override
  Future<void> createRule({
    required String baseTransactionId,
    required RecurringFrequency frequency,
    required int interval,
    required DateTime startDate,
    DateTime? endDate,
    required bool autoConfirm,
  }) async {
    final id = const Uuid().v4();
    await _dao.createRule(
      db.RecurringRulesCompanion.insert(
        id: id,
        baseTransactionId: baseTransactionId,
        frequency: frequency.name,
        interval: Value(interval),
        nextDate: startDate,
        endDate: Value(endDate),
        status: const Value('active'),
        autoConfirm: Value(autoConfirm),
      ),
    );
    // Gera transações imediatamente após criar
    await generatePendingTransactions();
  }

  @override
  Future<void> pauseRule(String id) => _dao.setStatus(id, 'paused');

  @override
  Future<void> resumeRule(String id) => _dao.setStatus(id, 'active');

  @override
  Future<void> deleteRule(String id) => _dao.deleteRule(id);

  @override
  Future<void> generatePendingTransactions({int daysAhead = 30}) async {
    final limit = DateTime.now().add(Duration(days: daysAhead));
    await _dao.generatePendingTransactions(limit);
    // Reconciliar lembretes é um efeito colateral best-effort — uma falha
    // aqui nunca deve interromper a geração das transações recorrentes.
    unawaited(ReminderScheduler(_database).reconcileAll().catchError((_) {}));
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<List<RecurringRuleModel>> _enrichRules(
    List<db.RecurringRule> rules,
  ) async {
    if (rules.isEmpty) return [];

    final result = <RecurringRuleModel>[];
    for (final rule in rules) {
      // Busca a transação-base para enriquecer com dados de exibição
      final baseTx = await (_database.select(
        _database.transactions,
      )..where((t) => t.id.equals(rule.baseTransactionId))).getSingleOrNull();

      String? categoryName;
      String? categoryColor;
      String? categoryIcon;
      int? amountInCents;
      String? accountId;

      if (baseTx != null) {
        // Busca categoria
        if (baseTx.categoryId != null) {
          final cat = await (_database.select(
            _database.categories,
          )..where((c) => c.id.equals(baseTx.categoryId!))).getSingleOrNull();
          categoryName = cat?.name;
          categoryColor = cat?.color;
          categoryIcon = cat?.icon;
        }

        // Busca entry para pegar o valor e accountId
        final entry =
            await (_database.select(_database.entries)
                  ..where((e) => e.transactionId.equals(baseTx.id))
                  ..limit(1))
                .getSingleOrNull();
        amountInCents = entry?.amount;
        accountId = entry?.accountId;
      }

      result.add(
        RecurringRuleModel.fromDb(
          rule,
          description: baseTx?.description,
          type: baseTx?.type,
          amountInCents: amountInCents,
          categoryId: baseTx?.categoryId,
          categoryName: categoryName,
          categoryColor: categoryColor,
          categoryIcon: categoryIcon,
          accountId: accountId,
        ),
      );
    }

    return result;
  }
}
