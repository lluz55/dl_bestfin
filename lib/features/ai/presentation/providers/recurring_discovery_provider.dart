import 'dart:math' show sqrt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/recurring/domain/models/recurring_rule.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

class RecurringDraftRule {
  final String description;
  final RecurringFrequency inferredFrequency;
  final int interval;
  final int amountInCents;
  final String? categoryId;
  final String? categoryName;
  final double confidence;
  final DateTime nextDate;

  const RecurringDraftRule({
    required this.description,
    required this.inferredFrequency,
    required this.interval,
    required this.amountInCents,
    this.categoryId,
    this.categoryName,
    required this.confidence,
    required this.nextDate,
  });
}

class _DismissedDraftsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void add(String key) => state = {...state, key};
}

final _dismissedDraftsProvider =
    NotifierProvider<_DismissedDraftsNotifier, Set<String>>(
      _DismissedDraftsNotifier.new,
    );

final recurringDiscoveryProvider = Provider<List<RecurringDraftRule>>((ref) {
  final txsAsync = ref.watch(filteredTransactionsProvider);
  final recurringAsync = ref.watch(activeRecurringProvider);
  final dismissed = ref.watch(_dismissedDraftsProvider);

  const empty = <RecurringDraftRule>[];

  return txsAsync.when(
    data: (txs) => recurringAsync.when(
      data: (existingRules) {
        final now = DateTime.now();
        final ninetyDaysAgo = now.subtract(const Duration(days: 90));

        final expenses = txs
            .where(
              (t) =>
                  t.isCompleted &&
                  t.type == TransactionType.expense &&
                  t.date.isAfter(ninetyDaysAgo),
            )
            .toList();

        // Group by (normalized description, categoryId)
        final Map<String, List<DateTime>> datesByKey = {};
        final Map<String, int> amountSumByKey = {};
        final Map<String, int> amountCountByKey = {};
        final Map<String, String?> categoryIdByKey = {};
        final Map<String, String?> categoryNameByKey = {};
        final Map<String, String> descriptionByKey = {};

        for (final tx in expenses) {
          final key =
              '${tx.description.toLowerCase().trim()}|${tx.categoryId ?? ''}';
          datesByKey[key] ??= [];
          datesByKey[key]!.add(tx.date);
          amountSumByKey[key] = (amountSumByKey[key] ?? 0) + tx.amount;
          amountCountByKey[key] = (amountCountByKey[key] ?? 0) + 1;
          categoryIdByKey[key] ??= tx.categoryId;
          categoryNameByKey[key] ??= tx.category?.name;
          descriptionByKey[key] ??= tx.description;
        }

        // Build set of existing rule dedup keys
        final existingKeys = existingRules
            .map(
              (r) =>
                  '${r.description?.toLowerCase().trim() ?? ''}|${r.frequency.name}',
            )
            .toSet();

        // Candidate periods: [days, RecurringFrequency]
        const periods = <(int, RecurringFrequency)>[
          (7, RecurringFrequency.weekly),
          (14, RecurringFrequency.biweekly),
          (30, RecurringFrequency.monthly),
          (365, RecurringFrequency.yearly),
        ];

        final List<RecurringDraftRule> drafts = [];

        for (final entry in datesByKey.entries) {
          final key = entry.key;
          final dates = entry.value;

          if (dates.length < 3) continue;

          dates.sort();

          final gaps = <int>[];
          for (int i = 1; i < dates.length; i++) {
            gaps.add(dates[i].difference(dates[i - 1]).inDays);
          }

          if (gaps.isEmpty) continue;

          final meanGap = gaps.fold<int>(0, (s, g) => s + g) / gaps.length;

          RecurringFrequency? bestFreq;
          double bestStddev = double.infinity;
          int bestPeriod = 0;

          for (final (period, freq) in periods) {
            // Accept if mean gap is within 30% of the target period
            if ((meanGap - period).abs() > period * 0.30) continue;

            final variance =
                gaps.fold<double>(
                  0,
                  (s, g) => s + (g - meanGap) * (g - meanGap),
                ) /
                gaps.length;
            final stddev = sqrt(variance);

            if (stddev < 3 && stddev < bestStddev) {
              bestStddev = stddev;
              bestFreq = freq;
              bestPeriod = period;
            }
          }

          if (bestFreq == null) continue;

          final dedupeKey =
              '${descriptionByKey[key]!.toLowerCase().trim()}|${bestFreq.name}';
          if (existingKeys.contains(dedupeKey)) continue;
          if (dismissed.contains(dedupeKey)) continue;

          final avgAmount = (amountSumByKey[key]! / amountCountByKey[key]!)
              .round();
          final confidence = (1.0 - (bestStddev / 3.0)).clamp(0.0, 1.0);

          final nextDate = dates.last.add(Duration(days: bestPeriod));

          drafts.add(
            RecurringDraftRule(
              description: descriptionByKey[key]!,
              inferredFrequency: bestFreq,
              interval: 1,
              amountInCents: avgAmount,
              categoryId: categoryIdByKey[key],
              categoryName: categoryNameByKey[key],
              confidence: confidence,
              nextDate: nextDate,
            ),
          );
        }

        drafts.sort((a, b) => b.confidence.compareTo(a.confidence));
        return drafts;
      },
      loading: () => empty,
      error: (_, __) => empty,
    ),
    loading: () => empty,
    error: (_, __) => empty,
  );
});

void dismissRecurringDraft(
  WidgetRef ref,
  String description,
  RecurringFrequency frequency,
) {
  final key = '${description.toLowerCase().trim()}|${frequency.name}';
  ref.read(_dismissedDraftsProvider.notifier).add(key);
}
