import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/investments/data/repositories/investment_repository.dart';
import 'package:bestfin/features/investments/domain/models/investment.dart';

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return InvestmentRepositoryImpl(db);
});

final investmentsStreamProvider = StreamProvider<List<Investment>>((ref) {
  final repo = ref.watch(investmentRepositoryProvider);
  return repo.watchAllInvestments();
});

class PortfolioSummary {
  final int totalInvested;
  final int totalYield;
  final int totalValue;
  final double yieldPercentage;
  final Map<String, int> allocationAmounts;
  final Map<String, double> allocationPercentages;

  const PortfolioSummary({
    required this.totalInvested,
    required this.totalYield,
    required this.totalValue,
    required this.yieldPercentage,
    required this.allocationAmounts,
    required this.allocationPercentages,
  });
}

final portfolioSummaryProvider = Provider<PortfolioSummary>((ref) {
  final investmentsAsync = ref.watch(investmentsStreamProvider);
  return investmentsAsync.when(
    data: (list) {
      int totalInvested = 0;
      int totalYield = 0;

      final Map<String, int> allocationAmounts = {};

      for (final inv in list) {
        totalInvested += inv.investedAmount;
        totalYield += inv.currentYield;

        allocationAmounts[inv.type] =
            (allocationAmounts[inv.type] ?? 0) + inv.totalValue;
      }

      final int totalValue = totalInvested + totalYield;
      final double yieldPercentage = totalInvested > 0
          ? (totalYield / totalInvested) * 100
          : 0.0;

      final Map<String, double> allocationPercentages = {};
      if (totalValue > 0) {
        allocationAmounts.forEach((type, val) {
          allocationPercentages[type] = val / totalValue;
        });
      }

      return PortfolioSummary(
        totalInvested: totalInvested,
        totalYield: totalYield,
        totalValue: totalValue,
        yieldPercentage: yieldPercentage,
        allocationAmounts: allocationAmounts,
        allocationPercentages: allocationPercentages,
      );
    },
    loading: () => const PortfolioSummary(
      totalInvested: 0,
      totalYield: 0,
      totalValue: 0,
      yieldPercentage: 0.0,
      allocationAmounts: {},
      allocationPercentages: {},
    ),
    error: (_, __) => const PortfolioSummary(
      totalInvested: 0,
      totalYield: 0,
      totalValue: 0,
      yieldPercentage: 0.0,
      allocationAmounts: {},
      allocationPercentages: {},
    ),
  );
});

final investmentByIdProvider = StreamProvider.family<Investment, String>((
  ref,
  id,
) {
  final repo = ref.watch(investmentRepositoryProvider);
  return Stream.fromFuture(repo.getInvestmentById(id));
});
