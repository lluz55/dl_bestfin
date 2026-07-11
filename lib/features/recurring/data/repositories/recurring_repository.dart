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

    // Enriquecimento em lote: em vez de 3 queries por regra (N+1), carregamos
    // transações-base, categorias e entries em uma consulta cada, indexadas por
    // id para montar o resultado sem novas idas ao banco.
    final baseIds = rules.map((r) => r.baseTransactionId).toSet().toList();

    final baseTxList = await (_database.select(
      _database.transactions,
    )..where((t) => t.id.isIn(baseIds))).get();
    final baseTxById = {for (final tx in baseTxList) tx.id: tx};

    final categoryIds = baseTxList
        .map((tx) => tx.categoryId)
        .whereType<String>()
        .toSet()
        .toList();
    final categoriesById = <String, db.Category>{};
    // childCategoryId → parentCategoryId, para exibir "Pai/Filho".
    final parentIdByChild = <String, String>{};
    if (categoryIds.isNotEmpty) {
      final rels = await _database.categoriesDao.getAllRelationships();
      for (final r in rels) {
        if (categoryIds.contains(r.childCategoryId)) {
          parentIdByChild.putIfAbsent(
            r.childCategoryId,
            () => r.parentCategoryId,
          );
        }
      }
      final neededIds = {...categoryIds, ...parentIdByChild.values}.toList();
      final categories = await (_database.select(
        _database.categories,
      )..where((c) => c.id.isIn(neededIds))).get();
      for (final cat in categories) {
        categoriesById[cat.id] = cat;
      }
    }

    // Primeira entry por transação-base (mesma semântica do `limit(1)` anterior).
    final firstEntryByTxId = <String, db.Entry>{};
    final entries = await (_database.select(
      _database.entries,
    )..where((e) => e.transactionId.isIn(baseIds))).get();
    for (final entry in entries) {
      firstEntryByTxId.putIfAbsent(entry.transactionId, () => entry);
    }

    return rules.map((rule) {
      final baseTx = baseTxById[rule.baseTransactionId];
      final cat = baseTx?.categoryId != null
          ? categoriesById[baseTx!.categoryId!]
          : null;
      final parent = cat != null
          ? categoriesById[parentIdByChild[cat.id]]
          : null;
      final categoryName = cat == null
          ? null
          : (parent != null ? '${parent.name}/${cat.name}' : cat.name);
      final entry = baseTx != null ? firstEntryByTxId[baseTx.id] : null;

      return RecurringRuleModel.fromDb(
        rule,
        description: baseTx?.description,
        type: baseTx?.type,
        amountInCents: entry?.amount,
        categoryId: baseTx?.categoryId,
        categoryName: categoryName,
        categoryColor: cat?.color,
        categoryIcon: cat?.icon,
        accountId: entry?.accountId,
      );
    }).toList();
  }
}
