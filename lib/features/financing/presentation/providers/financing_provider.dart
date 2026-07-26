import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/financing/data/repositories/financing_repository.dart';
import 'package:bestfin/features/financing/domain/models/financing.dart';
import 'package:bestfin/features/financing/domain/models/financing_installment.dart';

final financingRepositoryProvider = Provider<FinancingRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return FinancingRepositoryImpl(db);
});

final financingsStreamProvider = StreamProvider<List<Financing>>((ref) {
  final repo = ref.watch(financingRepositoryProvider);
  return repo.watchAllFinancings();
});

final financingByIdProvider = StreamProvider.family<Financing, String>((
  ref,
  id,
) {
  final repo = ref.watch(financingRepositoryProvider);
  return repo.watchFinancingById(id);
});

final financingInstallmentsProvider =
    StreamProvider.family<List<FinancingInstallment>, String>((
      ref,
      financingId,
    ) {
      final repo = ref.watch(financingRepositoryProvider);
      return repo.watchInstallmentsForFinancing(financingId);
    });

class FinancingSummary {
  final int totalOriginalAmount;
  final int totalOutstandingBalance;
  final double paidProgressPercentage;

  const FinancingSummary({
    required this.totalOriginalAmount,
    required this.totalOutstandingBalance,
    required this.paidProgressPercentage,
  });
}

final financingSummaryProvider = Provider<FinancingSummary>((ref) {
  final financingsAsync = ref.watch(financingsStreamProvider);
  return financingsAsync.when(
    data: (list) {
      int totalOriginalAmount = 0;
      int totalOutstandingBalance = 0;

      for (final fin in list) {
        totalOriginalAmount += fin.totalAmount;
        totalOutstandingBalance += fin.outstandingBalance;
      }

      final double progress = totalOriginalAmount > 0
          ? ((totalOriginalAmount - totalOutstandingBalance) /
                    totalOriginalAmount) *
                100
          : 0.0;

      return FinancingSummary(
        totalOriginalAmount: totalOriginalAmount,
        totalOutstandingBalance: totalOutstandingBalance,
        paidProgressPercentage: progress,
      );
    },
    loading: () => const FinancingSummary(
      totalOriginalAmount: 0,
      totalOutstandingBalance: 0,
      paidProgressPercentage: 0.0,
    ),
    error: (_, _) => const FinancingSummary(
      totalOriginalAmount: 0,
      totalOutstandingBalance: 0,
      paidProgressPercentage: 0.0,
    ),
  );
});
