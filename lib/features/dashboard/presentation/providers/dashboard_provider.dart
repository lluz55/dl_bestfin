import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/goals/presentation/providers/goals_provider.dart';
import 'package:bestfin/features/dashboard/domain/usecases/get_dashboard_data.dart';
import 'package:bestfin/features/dashboard/domain/models/dashboard_data.dart';

final getDashboardDataProvider = Provider<GetDashboardData>((ref) {
  final transactionRepository = ref.watch(transactionRepositoryProvider);
  final accountRepository = ref.watch(accountRepositoryProvider);
  final goalRepository = ref.watch(goalRepositoryProvider);
  return GetDashboardData(
    transactionRepository: transactionRepository,
    accountRepository: accountRepository,
    goalRepository: goalRepository,
  );
});

class DashboardPeriodNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final dashboardPeriodProvider =
    NotifierProvider<DashboardPeriodNotifier, int>(DashboardPeriodNotifier.new);

final dashboardProvider = StreamProvider<DashboardData>((ref) {
  final periodIndex = ref.watch(dashboardPeriodProvider);
  final getDashboardData = ref.watch(getDashboardDataProvider);
  return getDashboardData(periodIndex: periodIndex);
});
