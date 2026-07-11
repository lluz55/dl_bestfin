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
        required String name,
        required int year,
        required int month,
        required int amount,
        required List<String> categoryIds,
      })
    >((ref) {
      return ({
        required String name,
        required int year,
        required int month,
        required int amount,
        required List<String> categoryIds,
      }) =>
          ref
              .read(budgetRepositoryProvider)
              .createBudget(
                name: name,
                year: year,
                month: month,
                amount: amount,
                categoryIds: categoryIds,
              );
    });

final updateBudgetProvider =
    Provider<
      Future<void> Function(
        String id, {
        required String name,
        required int amount,
        required List<String> categoryIds,
      })
    >((ref) {
      return (
        id, {
        required String name,
        required int amount,
        required List<String> categoryIds,
      }) =>
          ref.read(budgetRepositoryProvider).updateBudget(
                id,
                name: name,
                amount: amount,
                categoryIds: categoryIds,
              );
    });

final deleteBudgetProvider = Provider<Future<void> Function(String id)>((ref) {
  return (id) => ref.read(budgetRepositoryProvider).deleteBudget(id);
});

final applyRolloverProvider =
    Provider<Future<void> Function(int year, int month)>((ref) {
      return (year, month) =>
          ref.read(budgetRepositoryProvider).applyRollover(year, month);
    });
