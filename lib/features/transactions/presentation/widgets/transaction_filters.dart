import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/animated_chip.dart';
import 'package:bestfin/core/utils/date_formatter.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';

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
    final activeAccounts = ref.read(activeAccountsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, child) {
                final currentFilters = ref.watch(transactionFiltersProvider);
                final selectedIds = currentFilters.accountIds;
                final accountIdSet = activeAccounts.map((a) => a.id).toSet();

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filtrar Contas',
                            style: context.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(transactionFiltersProvider.notifier)
                                  .update((state) {
                                final updated = state.accountIds
                                    .where((id) => !accountIdSet.contains(id))
                                    .toList();
                                return state.copyWith(accountIds: updated);
                              });
                            },
                            child: const Text('Limpar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            for (var account in activeAccounts)
                              _AccountFilterTile(
                                name: account.name,
                                icon: IconMapper.fromCodePoint(
                                  int.parse(account.icon),
                                ),
                                color: Color(
                                  int.parse(
                                    'FF${account.color.replaceFirst('#', '')}',
                                    radix: 16,
                                  ),
                                ),
                                isSelected: selectedIds.contains(account.id),
                                onTap: () => _toggleAccount(ref, account.id),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colorScheme.primary,
                            foregroundColor: context.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('APLICAR'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCreditCardFilter(BuildContext context, WidgetRef ref) {
    final creditCards = ref.read(creditCardsStreamProvider).value ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, child) {
                final currentFilters = ref.watch(transactionFiltersProvider);
                final selectedIds = currentFilters.creditCardIds;
                final cardIdSet = creditCards.map((c) => c.id).toSet();

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filtrar Cartões',
                            style: context.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(transactionFiltersProvider.notifier)
                                  .update((state) {
                                final updated = state.creditCardIds
                                    .where((id) => !cardIdSet.contains(id))
                                    .toList();
                                return state.copyWith(creditCardIds: updated);
                              });
                            },
                            child: const Text('Limpar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            for (var card in creditCards)
                              _AccountFilterTile(
                                name: card.name,
                                icon: Icons.credit_card_rounded,
                                color: Color(
                                  int.parse(
                                    'FF${(card.color ?? "#2196F3").replaceFirst('#', '')}',
                                    radix: 16,
                                  ),
                                ),
                                isSelected: selectedIds.contains(card.id),
                                onTap: () =>
                                    _toggleCreditCard(ref, card.id),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colorScheme.primary,
                            foregroundColor: context.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('APLICAR'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _toggleAccount(WidgetRef ref, String id) {
    ref.read(transactionFiltersProvider.notifier).update((state) {
      final current = List<String>.from(state.accountIds);
      if (current.contains(id)) {
        current.remove(id);
      } else {
        current.add(id);
      }
      return state.copyWith(accountIds: current);
    });
  }

  void _toggleCreditCard(WidgetRef ref, String id) {
    ref.read(transactionFiltersProvider.notifier).update((state) {
      final current = List<String>.from(state.creditCardIds);
      if (current.contains(id)) {
        current.remove(id);
      } else {
        current.add(id);
      }
      return state.copyWith(creditCardIds: current);
    });
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
    final creditCards = ref.watch(creditCardsStreamProvider).value ?? [];
    final categories = ref.watch(allFlatCategoriesProvider);

    String typeLabel = 'Tipo';
    if (filters.type != null) {
      typeLabel = TransactionType.fromString(filters.type!).label;
    }

    final selectedAccountIds = filters.accountIds
        .where((id) => accounts.any((a) => a.id == id))
        .toList();
    String accountLabel = 'Contas';
    if (selectedAccountIds.length == 1) {
      final acc =
          accounts.where((a) => a.id == selectedAccountIds.first).firstOrNull;
      accountLabel = acc?.name ?? '1 Conta';
    } else if (selectedAccountIds.length > 1) {
      accountLabel = '${selectedAccountIds.length} Contas';
    }

    final selectedCardIds = filters.creditCardIds
        .where((id) => creditCards.any((c) => c.id == id))
        .toList();
    String cardLabel = 'Cartões';
    if (selectedCardIds.length == 1) {
      final card = creditCards
          .where((c) => c.id == selectedCardIds.first)
          .firstOrNull;
      cardLabel = card?.name ?? '1 Cartão';
    } else if (selectedCardIds.length > 1) {
      cardLabel = '${selectedCardIds.length} Cartões';
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
          if (accounts.isNotEmpty) ...[
            const SizedBox(width: 8),
            AnimatedChip(
              label: accountLabel,
              icon: Icons.account_balance_outlined,
              selected: selectedAccountIds.isNotEmpty,
              onTap: () => _showAccountFilter(context, ref),
              delay: const Duration(milliseconds: 50),
            ),
          ],
          if (creditCards.isNotEmpty) ...[
            const SizedBox(width: 8),
            AnimatedChip(
              label: cardLabel,
              icon: Icons.credit_card_outlined,
              selected: selectedCardIds.isNotEmpty,
              onTap: () => _showCreditCardFilter(context, ref),
              delay: const Duration(milliseconds: 100),
            ),
          ],
          const SizedBox(width: 8),
          AnimatedChip(
            label: categoryLabel,
            icon: Icons.category_outlined,
            selected: filters.categoryId != null,
            onTap: () => _showCategoryFilter(context, ref),
            delay: const Duration(milliseconds: 150),
          ),
          const SizedBox(width: 8),
          AnimatedChip(
            label: dateLabel,
            icon: Icons.calendar_month_outlined,
            selected: filters.startDate != null,
            onTap: () => _showDateFilter(context, ref),
            delay: const Duration(milliseconds: 200),
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

class _AccountFilterTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountFilterTile({
    required this.name,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        name,
        style: context.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (_) => onTap(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onTap: onTap,
    );
  }
}
