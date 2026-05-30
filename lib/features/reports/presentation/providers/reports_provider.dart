import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/reports/domain/models/sankey_models.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_category_report.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_monthly_report.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_cash_flow.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_net_worth.dart';
import 'package:bestfin/features/reports/domain/usecases/generate_sankey_report.dart';

// ─── Filters ────────────────────────────────────────────────────────────────

enum ReportPeriod { month, quarter, year, custom }

class ReportFilters {
  final ReportPeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;
  final List<String> accountIds;
  final List<String> creditCardIds;
  final String? categoryId;
  final String? type; // income | expense | transfer | null

  const ReportFilters({
    this.period = ReportPeriod.month,
    this.customStart,
    this.customEnd,
    this.accountIds = const [],
    this.creditCardIds = const [],
    this.categoryId,
    this.type,
  });

  DateTime get startDate {
    final now = DateTime.now();
    switch (period) {
      case ReportPeriod.month:
        return DateTime(now.year, now.month, 1);
      case ReportPeriod.quarter:
        final q = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, q, 1);
      case ReportPeriod.year:
        return DateTime(now.year, 1, 1);
      case ReportPeriod.custom:
        return customStart ?? DateTime(now.year, now.month, 1);
    }
  }

  DateTime get endDate {
    final now = DateTime.now();
    switch (period) {
      case ReportPeriod.month:
        return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case ReportPeriod.quarter:
        final q = ((now.month - 1) ~/ 3) * 3 + 3;
        return DateTime(now.year, q + 1, 0, 23, 59, 59);
      case ReportPeriod.year:
        return DateTime(now.year, 12, 31, 23, 59, 59);
      case ReportPeriod.custom:
        return customEnd ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }
  }

  ReportFilters copyWith({
    ReportPeriod? period,
    DateTime? customStart,
    DateTime? customEnd,
    List<String>? accountIds,
    List<String>? creditCardIds,
    String? categoryId,
    String? type,
    bool clearAccounts = false,
    bool clearCreditCards = false,
    bool clearCategory = false,
    bool clearType = false,
  }) {
    return ReportFilters(
      period: period ?? this.period,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      accountIds: clearAccounts ? const [] : (accountIds ?? this.accountIds),
      creditCardIds: clearCreditCards ? const [] : (creditCardIds ?? this.creditCardIds),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      type: clearType ? null : (type ?? this.type),
    );
  }
}

class ReportFiltersNotifier extends Notifier<ReportFilters> {
  @override
  ReportFilters build() => const ReportFilters();

  void update(ReportFilters Function(ReportFilters) cb) {
    state = cb(state);
  }
}

final reportFiltersProvider =
    NotifierProvider<ReportFiltersNotifier, ReportFilters>(
      () => ReportFiltersNotifier(),
    );

// ─── Use Case Providers ─────────────────────────────────────────────────────

final generateCategoryReportProvider = Provider<GenerateCategoryReport>((ref) {
  return GenerateCategoryReport(ref.watch(transactionRepositoryProvider));
});

final generateMonthlyReportProvider = Provider<GenerateMonthlyReport>((ref) {
  return GenerateMonthlyReport(ref.watch(transactionRepositoryProvider));
});

final generateCashFlowProvider = Provider<GenerateCashFlow>((ref) {
  return GenerateCashFlow(ref.watch(transactionRepositoryProvider));
});

final generateNetWorthProvider = Provider<GenerateNetWorth>((ref) {
  return GenerateNetWorth(
    transactionRepository: ref.watch(transactionRepositoryProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    database: ref.watch(databaseProvider),
  );
});

// ─── Data Providers ─────────────────────────────────────────────────────────

final categoryReportProvider = StreamProvider<CategoryReport>((ref) {
  final useCase = ref.watch(generateCategoryReportProvider);
  final filters = ref.watch(reportFiltersProvider);
  return useCase(
    startDate: filters.startDate,
    endDate: filters.endDate,
    accountIds: filters.accountIds,
    creditCardIds: filters.creditCardIds,
  );
});

final monthlyReportProvider = StreamProvider<MonthlyReport>((ref) {
  final useCase = ref.watch(generateMonthlyReportProvider);
  final filters = ref.watch(reportFiltersProvider);
  final months = filters.period == ReportPeriod.year ? 12 : 6;
  return useCase(
    months: months,
    accountIds: filters.accountIds,
    creditCardIds: filters.creditCardIds,
  );
});

final cashFlowProvider = StreamProvider<CashFlowReport>((ref) {
  final useCase = ref.watch(generateCashFlowProvider);
  final filters = ref.watch(reportFiltersProvider);
  return useCase(
    startDate: filters.startDate,
    endDate: filters.endDate,
    accountIds: filters.accountIds,
    creditCardIds: filters.creditCardIds,
  );
});

final netWorthProvider = StreamProvider<NetWorthReport>((ref) {
  final useCase = ref.watch(generateNetWorthProvider);
  final filters = ref.watch(reportFiltersProvider);
  final months = filters.period == ReportPeriod.year ? 12 : 6;
  return useCase(months: months);
});

final generateSankeyReportProvider = Provider<GenerateSankeyReport>((ref) {
  return GenerateSankeyReport(ref.watch(transactionRepositoryProvider));
});

final sankeyReportProvider = StreamProvider<SankeyData>((ref) {
  final useCase = ref.watch(generateSankeyReportProvider);
  final filters = ref.watch(reportFiltersProvider);
  return useCase(
    startDate: filters.startDate,
    endDate: filters.endDate,
    accountIds: filters.accountIds,
    creditCardIds: filters.creditCardIds,
  );
});
