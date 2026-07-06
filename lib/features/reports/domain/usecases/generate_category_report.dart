import 'package:bestfin/features/categories/domain/models/category.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/core/constants/transaction_types.dart';

class GenerateCategoryReport {
  final TransactionRepository _repository;

  GenerateCategoryReport(this._repository);

  Stream<CategoryReport> call({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? accountIds,
    List<String>? creditCardIds,
  }) {
    return _repository
        .watchTransactionsWithFilters(
          type: 'expense',
          accountIds: accountIds,
          creditCardIds: creditCardIds,
          startDate: startDate,
          endDate: endDate,
        )
        .map((transactions) {
          final Map<String, _Group> groups = {};
          int total = 0;

          for (final tx in transactions) {
            if (tx.type != TransactionType.expense) continue;

            final catId = tx.categoryId ?? '_none';
            final g = groups[catId] ?? _Group(tx.category, 0, 0);
            if (tx.isCompleted) {
              groups[catId] = _Group(
                g.category,
                g.amount + tx.amount,
                g.pending,
              );
              total += tx.amount;
            } else {
              groups[catId] = _Group(
                g.category,
                g.amount,
                g.pending + tx.amount,
              );
            }
          }

          final sorted = groups.values.toList()
            ..sort((a, b) => b.amount.compareTo(a.amount));

          const maxSlices = 5;
          final List<CategorySpending> items = [];

          if (sorted.length <= maxSlices) {
            for (final g in sorted) {
              items.add(
                CategorySpending(
                  category: g.category,
                  amountInCents: g.amount,
                  percentage: total > 0 ? g.amount / total : 0,
                  pendingAmountInCents: g.pending,
                ),
              );
            }
          } else {
            for (int i = 0; i < maxSlices - 1; i++) {
              final g = sorted[i];
              items.add(
                CategorySpending(
                  category: g.category,
                  amountInCents: g.amount,
                  percentage: total > 0 ? g.amount / total : 0,
                  pendingAmountInCents: g.pending,
                ),
              );
            }
            int othersAmount = 0;
            int othersPending = 0;
            for (int i = maxSlices - 1; i < sorted.length; i++) {
              othersAmount += sorted[i].amount;
              othersPending += sorted[i].pending;
            }
            items.add(
              CategorySpending(
                category: CategoryModel(
                  id: '_others',
                  name: 'Outros',
                  icon: 'more_horiz',
                  color: '9E9E9E',
                  type: 'expense',
                  isSystem: true,
                  isArchived: false,
                  createdAt: DateTime.now(),
                ),
                amountInCents: othersAmount,
                percentage: total > 0 ? othersAmount / total : 0,
                pendingAmountInCents: othersPending,
              ),
            );
          }

          return CategoryReport(
            items: items,
            totalExpense: total,
            startDate: startDate,
            endDate: endDate,
          );
        });
  }
}

class _Group {
  final CategoryModel? category;
  final int amount;
  final int pending;
  const _Group(this.category, this.amount, this.pending);
}
