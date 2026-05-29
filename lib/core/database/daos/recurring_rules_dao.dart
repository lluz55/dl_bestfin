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

  Future<void> createRule(RecurringRulesCompanion companion) {
    return into(recurringRules).insert(companion);
  }

  Future<void> updateRule(RecurringRulesCompanion companion) {
    return (update(
      recurringRules,
    )..where((r) => r.id.equals(companion.id.value))).write(companion);
  }

  Future<void> setStatus(String id, String status) {
    return (update(recurringRules)..where((r) => r.id.equals(id))).write(
      RecurringRulesCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateNextDate(String id, DateTime nextDate) {
    return (update(recurringRules)..where((r) => r.id.equals(id))).write(
      RecurringRulesCompanion(
        nextDate: Value(nextDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteRule(String id) {
    return (delete(recurringRules)..where((r) => r.id.equals(id))).go();
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
        // Evita duplicatas: verifica se já existe uma transação nessa data com
        // a mesma descrição e tipo gerada por essa regra.
        final existingQuery = select(transactions)
          ..where(
            (t) =>
                t.description.equals(baseTx.description) &
                t.type.equals(baseTx.type) &
                t.date.equals(current),
          );
        final existing = await existingQuery.getSingleOrNull();

        if (existing == null) {
          final newTxId = const Uuid().v4();
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
              isCompleted: Value(rule.autoConfirm),
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
