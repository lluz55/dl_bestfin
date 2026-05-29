import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/animated_chip.dart';
import 'package:bestfin/core/utils/date_formatter.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';

class TransactionFiltersWidget extends ConsumerWidget {
  const TransactionFiltersWidget({super.key});

  void _showTypeFilter(BuildContext context, WidgetRef ref) {
    final filters = ref.read(transactionFiltersProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtrar por Tipo',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Todos'),
                  leading: const Icon(Icons.all_inclusive),
                  selected: filters.type == null,
                  onTap: () {
                    ref
                        .read(transactionFiltersProvider.notifier)
                        .update((state) => state.copyWith(clearType: true));
                    Navigator.of(context).pop();
                  },
                ),
                for (var type in TransactionType.values)
                  ListTile(
                    title: Text(type.label),
                    leading: Icon(
                      type == TransactionType.income
                          ? Icons.arrow_downward
                          : type == TransactionType.expense
                          ? Icons.arrow_upward
                          : Icons.swap_horiz,
                    ),
                    selected: filters.type == type.name,
                    onTap: () {
                      ref
                          .read(transactionFiltersProvider.notifier)
                          .update((state) => state.copyWith(type: type.name));
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAccountFilter(BuildContext context, WidgetRef ref) {
    final filters = ref.read(transactionFiltersProvider);
    final activeAccounts = ref.read(activeAccountsProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtrar por Conta',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        title: const Text('Todas as Contas'),
                        leading: const Icon(
                          Icons.account_balance_wallet_outlined,
                        ),
                        selected: filters.accountId == null,
                        onTap: () {
                          ref
                              .read(transactionFiltersProvider.notifier)
                              .update(
                                (state) => state.copyWith(clearAccount: true),
                              );
                          Navigator.of(context).pop();
                        },
                      ),
                      for (var account in activeAccounts)
                        ListTile(
                          title: Text(account.name),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  'FF${account.color.replaceFirst('#', '')}',
                                  radix: 16,
                                ),
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              IconData(
                                int.parse(account.icon),
                                fontFamily: 'MaterialIcons',
                              ),
                              color: Color(
                                int.parse(
                                  'FF${account.color.replaceFirst('#', '')}',
                                  radix: 16,
                                ),
                              ),
                            ),
                          ),
                          selected: filters.accountId == account.id,
                          onTap: () {
                            ref
                                .read(transactionFiltersProvider.notifier)
                                .update(
                                  (state) =>
                                      state.copyWith(accountId: account.id),
                                );
                            Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCategoryFilter(BuildContext context, WidgetRef ref) {
    final filters = ref.read(transactionFiltersProvider);
    final categories = ref.read(allFlatCategoriesProvider);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtrar por Categoria',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        title: const Text('Todas as Categorias'),
                        leading: const Icon(Icons.category_outlined),
                        selected: filters.categoryId == null,
                        onTap: () {
                          ref
                              .read(transactionFiltersProvider.notifier)
                              .update(
                                (state) => state.copyWith(clearCategory: true),
                              );
                          Navigator.of(context).pop();
                        },
                      ),
                      for (var category in categories)
                        ListTile(
                          title: Text(category.name),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: category.parsedColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              category.iconData,
                              color: category.parsedColor,
                            ),
                          ),
                          selected: filters.categoryId == category.id,
                          onTap: () {
                            ref
                                .read(transactionFiltersProvider.notifier)
                                .update(
                                  (state) =>
                                      state.copyWith(categoryId: category.id),
                                );
                            Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDateFilter(BuildContext context, WidgetRef ref) async {
    final filters = ref.read(transactionFiltersProvider);

    final selectedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: filters.startDate != null && filters.endDate != null
          ? DateTimeRange(start: filters.startDate!, end: filters.endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: Theme.of(context).appBarTheme.copyWith(
              backgroundColor: context.colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedRange != null) {
      ref
          .read(transactionFiltersProvider.notifier)
          .update(
            (state) => state.copyWith(
              startDate: selectedRange.start,
              endDate: selectedRange.end,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(transactionFiltersProvider);
    final accounts = ref.watch(activeAccountsProvider);
    final categories = ref.watch(allFlatCategoriesProvider);

    String typeLabel = 'Tipo';
    if (filters.type != null) {
      typeLabel = TransactionType.fromString(filters.type!).label;
    }

    String accountLabel = 'Conta';
    if (filters.accountId != null) {
      final acc = accounts.firstWhere(
        (a) => a.id == filters.accountId,
        orElse: () => accounts.first,
      );
      accountLabel = acc.name;
    }

    String categoryLabel = 'Categoria';
    if (filters.categoryId != null) {
      final cat = categories.firstWhere(
        (c) => c.id == filters.categoryId,
        orElse: () => categories.first,
      );
      categoryLabel = cat.name;
    }

    String dateLabel = 'Período';
    if (filters.startDate != null && filters.endDate != null) {
      dateLabel =
          '${DateFormatter.formatDate(filters.startDate!)} - ${DateFormatter.formatDate(filters.endDate!)}';
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AnimatedChip(
            label: typeLabel,
            icon: Icons.filter_alt_outlined,
            selected: filters.type != null,
            onTap: () => _showTypeFilter(context, ref),
          ),
          const SizedBox(width: 8),
          AnimatedChip(
            label: accountLabel,
            icon: Icons.account_balance_wallet_outlined,
            selected: filters.accountId != null,
            onTap: () => _showAccountFilter(context, ref),
            delay: const Duration(milliseconds: 50),
          ),
          const SizedBox(width: 8),
          AnimatedChip(
            label: categoryLabel,
            icon: Icons.category_outlined,
            selected: filters.categoryId != null,
            onTap: () => _showCategoryFilter(context, ref),
            delay: const Duration(milliseconds: 100),
          ),
          const SizedBox(width: 8),
          AnimatedChip(
            label: dateLabel,
            icon: Icons.calendar_month_outlined,
            selected: filters.startDate != null,
            onTap: () => _showDateFilter(context, ref),
            delay: const Duration(milliseconds: 150),
          ),
          if (!filters.isEmpty) ...[
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Limpar filtros',
              onPressed: () {
                ref.read(transactionFiltersProvider.notifier).state =
                    const TransactionFilters();
              },
            ),
          ],
        ],
      ),
    );
  }
}
