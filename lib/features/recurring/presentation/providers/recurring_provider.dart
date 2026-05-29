import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/recurring/data/repositories/recurring_repository.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return RecurringRepositoryImpl(database);
});

// ── Streams por status ────────────────────────────────────────────────────────

final activeRecurringProvider = StreamProvider<List<RecurringRuleModel>>((ref) {
  return ref
      .watch(recurringRepositoryProvider)
      .watchByStatus(RecurringStatus.active);
});

final pausedRecurringProvider = StreamProvider<List<RecurringRuleModel>>((ref) {
  return ref
      .watch(recurringRepositoryProvider)
      .watchByStatus(RecurringStatus.paused);
});

final finishedRecurringProvider = StreamProvider<List<RecurringRuleModel>>((
  ref,
) {
  return ref
      .watch(recurringRepositoryProvider)
      .watchByStatus(RecurringStatus.finished);
});

final allRecurringProvider = StreamProvider<List<RecurringRuleModel>>((ref) {
  return ref.watch(recurringRepositoryProvider).watchAll();
});

// ── Stats para o hub de assinaturas ──────────────────────────────────────────

class RecurringStats {
  final double totalMonthlyInCents;
  final Map<String, double> breakdownByCategory; // categoryName -> cents/month

  const RecurringStats({
    required this.totalMonthlyInCents,
    required this.breakdownByCategory,
  });
}

final recurringStatsProvider = Provider<AsyncValue<RecurringStats>>((ref) {
  final asyncRules = ref.watch(activeRecurringProvider);
  return asyncRules.whenData((rules) {
    double total = 0;
    final breakdown = <String, double>{};

    for (final rule in rules) {
      if (rule.type == 'expense') {
        final monthly = rule.monthlyEquivalentInCents;
        total += monthly;
        final catKey = rule.categoryName ?? 'Sem categoria';
        breakdown[catKey] = (breakdown[catKey] ?? 0) + monthly;
      }
    }

    return RecurringStats(
      totalMonthlyInCents: total,
      breakdownByCategory: breakdown,
    );
  });
});

// ── Geração de transações pendentes ──────────────────────────────────────────

final generateRecurringProvider = FutureProvider<void>((ref) {
  return ref.watch(recurringRepositoryProvider).generatePendingTransactions();
});

// ── Actions ───────────────────────────────────────────────────────────────────

final createRecurringRuleProvider =
    Provider<
      Future<void> Function({
        required String baseTransactionId,
        required RecurringFrequency frequency,
        required int interval,
        required DateTime startDate,
        DateTime? endDate,
        required bool autoConfirm,
      })
    >((ref) {
      final repo = ref.watch(recurringRepositoryProvider);
      return ({
        required String baseTransactionId,
        required RecurringFrequency frequency,
        required int interval,
        required DateTime startDate,
        DateTime? endDate,
        required bool autoConfirm,
      }) => repo.createRule(
        baseTransactionId: baseTransactionId,
        frequency: frequency,
        interval: interval,
        startDate: startDate,
        endDate: endDate,
        autoConfirm: autoConfirm,
      );
    });

final pauseRecurringProvider = Provider<Future<void> Function(String)>((ref) {
  return ref.watch(recurringRepositoryProvider).pauseRule;
});

final resumeRecurringProvider = Provider<Future<void> Function(String)>((ref) {
  return ref.watch(recurringRepositoryProvider).resumeRule;
});

final deleteRecurringProvider = Provider<Future<void> Function(String)>((ref) {
  return ref.watch(recurringRepositoryProvider).deleteRule;
});
