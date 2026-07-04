import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/tables/recurring_rules.dart';
import 'package:bestfin/core/database/tables/transactions.dart';
import 'package:bestfin/core/database/tables/entries.dart';

part 'recurring_rules_dao.g.dart';

@DriftAccessor(tables: [RecurringRules, Transactions, Entries])
class RecurringRulesDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringRulesDaoMixin {
  RecurringRulesDao(super.db);

  // ── Reads ──────────────────────────────────────────────────────────────────

  Stream<List<RecurringRule>> watchByStatus(String status) {
    return (select(recurringRules)
          ..where((r) => r.status.equals(status))
          ..orderBy([(r) => OrderingTerm(expression: r.nextDate)]))
        .watch();
  }

  Stream<List<RecurringRule>> watchAll() {
    return (select(
      recurringRules,
    )..orderBy([(r) => OrderingTerm(expression: r.nextDate)])).watch();
  }

  Future<RecurringRule?> findById(String id) {
    return (select(
      recurringRules,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Retorna todas as regras ativas cuja nextDate <= limite (para geração).
  Future<List<RecurringRule>> getDueRules(DateTime limit) {
    return (select(recurringRules)..where(
          (r) =>
              r.status.equals('active') &
              r.nextDate.isSmallerOrEqualValue(limit),
        ))
        .get();
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  Future<void> createRule(RecurringRulesCompanion companion) async {
    await into(recurringRules).insert(companion);
    await _enqueueRecurringRuleSync(companion.id.value, 'insert');
  }

  Future<void> updateRule(RecurringRulesCompanion companion) async {
    final id = companion.id.value;
    await (update(
      recurringRules,
    )..where((r) => r.id.equals(id))).write(companion);
    await _enqueueRecurringRuleSync(id, 'update');
  }

  Future<void> setStatus(String id, String status) async {
    await (update(recurringRules)..where((r) => r.id.equals(id))).write(
      RecurringRulesCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _enqueueRecurringRuleSync(id, 'update');
  }

  Future<void> updateNextDate(String id, DateTime nextDate) async {
    await (update(recurringRules)..where((r) => r.id.equals(id))).write(
      RecurringRulesCompanion(
        nextDate: Value(nextDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _enqueueRecurringRuleSync(id, 'update');
  }

  Future<int> deleteRule(String id) async {
    await _enqueueRecurringRuleSync(id, 'delete');
    return (delete(recurringRules)..where((r) => r.id.equals(id))).go();
  }

  Future<void> _enqueueRecurringRuleSync(String id, String operation) async {
    final rule = await findById(id);

    final payload = rule == null
        ? <String, dynamic>{'id': id}
        : <String, dynamic>{
            'id': rule.id,
            'base_transaction_id': rule.baseTransactionId,
            'frequency': rule.frequency,
            'interval': rule.interval,
            'next_date': rule.nextDate.toIso8601String(),
            'end_date': rule.endDate?.toIso8601String(),
            'status': rule.status,
            'auto_confirm': rule.autoConfirm,
            'created_at': rule.createdAt.toIso8601String(),
            'updated_at': rule.updatedAt.toIso8601String(),
          };

    await db.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: 'recurring_rule',
      entityId: id,
      payload: jsonEncode(payload),
    );
  }

  Future<RecurringRule?> findByBaseTransactionId(String txId) {
    return (select(
      recurringRules,
    )..where((r) => r.baseTransactionId.equals(txId))).getSingleOrNull();
  }

  Future<List<Transaction>> getGeneratedTransactions(String ruleId) {
    return (select(
      transactions,
    )..where((t) => t.recurringRuleId.equals(ruleId))).get();
  }

  Future<List<Transaction>> getFutureGeneratedTransactions(
    String ruleId,
    DateTime after,
  ) {
    return (select(transactions)..where(
          (t) =>
              t.recurringRuleId.equals(ruleId) &
              t.date.isBiggerThanValue(after),
        ))
        .get();
  }

  // ── Generation ─────────────────────────────────────────────────────────────

  /// Gera transações pendentes para todas as regras ativas até [limit].
  Future<void> generatePendingTransactions(DateTime limit) async {
    final dueRules = await getDueRules(limit);
    for (final rule in dueRules) {
      await _generateForRule(rule, limit);
    }
  }

  /// Gera transações pendentes para uma regra específica até [limit].
  Future<void> _generateForRule(RecurringRule rule, DateTime limit) async {
    final baseTx = await (select(
      transactions,
    )..where((t) => t.id.equals(rule.baseTransactionId))).getSingleOrNull();
    if (baseTx == null) return;

    final baseEntries = await (select(
      entries,
    )..where((e) => e.transactionId.equals(rule.baseTransactionId))).get();

    DateTime current = rule.nextDate;

    await db.transaction(() async {
      while (!current.isAfter(limit)) {
        // Evita duplicatas: verifica se já existe uma ocorrência gerada por essa
        // regra nessa data exata.
        final existingQuery = select(transactions)
          ..where(
            (t) => t.recurringRuleId.equals(rule.id) & t.date.equals(current),
          );
        final existing = await existingQuery.getSingleOrNull();

        if (existing == null) {
          final newTxId = const Uuid().v4();
          final isTransfer = baseTx.type == 'transfer';
          await into(transactions).insert(
            TransactionsCompanion.insert(
              id: newTxId,
              date: current,
              description: baseTx.description,
              type: baseTx.type,
              categoryId: Value(baseTx.categoryId),
              entityId: Value(baseTx.entityId),
              notes: Value(baseTx.notes),
              sentiment: Value(baseTx.sentiment),
              isCompleted: Value(isTransfer ? false : rule.autoConfirm),
              isConfirmed: Value(isTransfer ? false : rule.autoConfirm),
              recurringRuleId: Value(rule.id),
            ),
          );

          for (final entry in baseEntries) {
            await into(entries).insert(
              EntriesCompanion.insert(
                id: const Uuid().v4(),
                transactionId: newTxId,
                accountId: entry.accountId,
                amount: entry.amount,
                type: entry.type,
              ),
            );
          }
        }

        current = _advance(current, rule.frequency, rule.interval);

        if (rule.endDate != null && current.isAfter(rule.endDate!)) break;
      }

      await updateNextDate(rule.id, current);

      if (rule.endDate != null && current.isAfter(rule.endDate!)) {
        await setStatus(rule.id, 'finished');
      }
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Calcula a próxima data com base na frequência e intervalo.
  static DateTime advanceDate(DateTime from, String frequency, int interval) {
    switch (frequency) {
      case 'daily':
        return from.add(Duration(days: interval));
      case 'weekly':
        return from.add(Duration(days: 7 * interval));
      case 'biweekly':
        return from.add(Duration(days: 14 * interval));
      case 'monthly':
        return DateTime(
          from.year,
          from.month + interval,
          from.day,
          from.hour,
          from.minute,
        );
      case 'yearly':
        return DateTime(
          from.year + interval,
          from.month,
          from.day,
          from.hour,
          from.minute,
        );
      default:
        return from.add(Duration(days: interval));
    }
  }

  DateTime _advance(DateTime from, String frequency, int interval) =>
      RecurringRulesDao.advanceDate(from, frequency, interval);
}
