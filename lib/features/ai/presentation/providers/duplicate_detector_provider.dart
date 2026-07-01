import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

class DuplicatePair {
  final TransactionModel original;
  final TransactionModel duplicate;

  const DuplicatePair({required this.original, required this.duplicate});
}

class _DismissedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void add(String id) => state = {...state, id};
}

final _dismissedDuplicatesProvider =
    NotifierProvider<_DismissedNotifier, Set<String>>(_DismissedNotifier.new);

final duplicateDetectorProvider = Provider<List<DuplicatePair>>((ref) {
  final txsAsync = ref.watch(filteredTransactionsProvider);
  final dismissed = ref.watch(_dismissedDuplicatesProvider);

  return txsAsync.when(
    data: (txs) {
      if (txs.length < 2) return [];

      final now = DateTime.now();
      final twoHoursAgo = now.subtract(const Duration(hours: 2));

      final recent = txs
          .where((t) => t.updatedAt.isAfter(twoHoursAgo))
          .toList();
      if (recent.isEmpty) return [];

      final pairs = <DuplicatePair>[];
      final seenDuplicateIds = <String>{};

      for (final candidate in recent) {
        if (dismissed.contains(candidate.id)) continue;
        if (seenDuplicateIds.contains(candidate.id)) continue;

        for (final existing in txs) {
          if (existing.id == candidate.id) continue;
          if (!existing.updatedAt.isBefore(candidate.updatedAt)) continue;

          final amountDiff = (existing.amount - candidate.amount).abs();
          final dateDiffMinutes = existing.date
              .difference(candidate.date)
              .inMinutes
              .abs();

          if (amountDiff <= 50 &&
              dateDiffMinutes <= 120 &&
              existing.categoryId == candidate.categoryId &&
              existing.categoryId != null) {
            pairs.add(DuplicatePair(original: existing, duplicate: candidate));
            seenDuplicateIds.add(candidate.id);
            break;
          }
        }
      }

      return pairs;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

void dismissDuplicate(WidgetRef ref, String duplicateId) {
  ref.read(_dismissedDuplicatesProvider.notifier).add(duplicateId);
}
