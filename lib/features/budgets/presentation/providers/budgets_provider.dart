import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/budgets/data/repositories/budget_repository.dart';
import 'package:bestfin/features/budgets/domain/models/budget_model.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepositoryImpl(ref.watch(databaseProvider));
});

final budgetsForPeriodProvider =
    StreamProvider.family<List<BudgetModel>, (int, int)>((ref, period) {
      return ref
          .watch(budgetRepositoryProvider)
          .watchBudgetsForPeriod(period.$1, period.$2);
    });

final currentPeriodBudgetsProvider = StreamProvider<List<BudgetModel>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(budgetRepositoryProvider)
      .watchBudgetsForPeriod(now.year, now.month);
});

final createBudgetProvider =
    Provider<
      Future<void> Function({
        required String categoryId,
        required int year,
        required int month,
        required int amount,
      })
    >((ref) {
      return ({
        required String categoryId,
        required int year,
        required int month,
        required int amount,
      }) => ref
          .read(budgetRepositoryProvider)
          .createBudget(
            categoryId: categoryId,
            year: year,
            month: month,
            amount: amount,
          );
    });

final updateBudgetProvider =
    Provider<Future<void> Function(String id, int amount)>((ref) {
      return (id, amount) =>
          ref.read(budgetRepositoryProvider).updateBudget(id, amount);
    });

final deleteBudgetProvider = Provider<Future<void> Function(String id)>((ref) {
  return (id) => ref.read(budgetRepositoryProvider).deleteBudget(id);
});

final applyRolloverProvider =
    Provider<Future<void> Function(int year, int month)>((ref) {
      return (year, month) =>
          ref.read(budgetRepositoryProvider).applyRollover(year, month);
    });
