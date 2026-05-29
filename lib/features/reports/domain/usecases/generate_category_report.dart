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
    String? accountId,
  }) {
    return _repository
        .watchTransactionsWithFilters(
          type: 'expense',
          accountId: accountId,
          startDate: startDate,
          endDate: endDate,
        )
        .map((transactions) {
          final Map<String, _Group> groups = {};
          int total = 0;

          for (final tx in transactions) {
            if (!tx.isCompleted) continue;
            if (tx.type != TransactionType.expense) continue;

            final catId = tx.categoryId ?? '_none';
            final g = groups[catId] ?? _Group(tx.category, 0);
            groups[catId] = _Group(g.category, g.amount + tx.amount);
            total += tx.amount;
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
                ),
              );
            }
            int othersAmount = 0;
            for (int i = maxSlices - 1; i < sorted.length; i++) {
              othersAmount += sorted[i].amount;
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
  const _Group(this.category, this.amount);
}
