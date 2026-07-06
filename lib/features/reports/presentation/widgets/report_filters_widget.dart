import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/animated_chip.dart';
import 'package:bestfin/core/utils/date_formatter.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';
import 'package:bestfin/features/reports/presentation/providers/reports_provider.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';

class ReportFiltersWidget extends ConsumerWidget {
  const ReportFiltersWidget({super.key});

  void _showPeriodFilter(BuildContext context, WidgetRef ref) {
    final filters = ref.read(reportFiltersProvider);
    final notifier = ref.read(reportFiltersProvider.notifier);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtrar por Período',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Mês atual'),
                  leading: const Icon(Icons.calendar_view_month_outlined),
                  selected: filters.period == ReportPeriod.month,
                  onTap: () {
                    notifier.update(
                      (f) => f.copyWith(period: ReportPeriod.month),
                    );
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: const Text('Trimestre'),
                  leading: const Icon(Icons.calendar_view_week_outlined),
                  selected: filters.period == ReportPeriod.quarter,
                  onTap: () {
                    notifier.update(
                      (f) => f.copyWith(period: ReportPeriod.quarter),
                    );
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: const Text('Ano'),
                  leading: const Icon(Icons.calendar_today_outlined),
                  selected: filters.period == ReportPeriod.year,
                  onTap: () {
                    notifier.update(
                      (f) => f.copyWith(period: ReportPeriod.year),
                    );
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: const Text('Personalizado'),
                  leading: const Icon(Icons.date_range_outlined),
                  selected: filters.period == ReportPeriod.custom,
                  onTap: () async {
                    Navigator.of(context).pop();
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 3),
                      lastDate: now,
                      initialDateRange: DateTimeRange(
                        start:
                            filters.customStart ??
                            DateTime(now.year, now.month, 1),
                        end: filters.customEnd ?? now,
                      ),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          appBarTheme: Theme.of(context).appBarTheme.copyWith(
                            backgroundColor: context.colorScheme.surface,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      notifier.update(
                        (f) => f.copyWith(
                          period: ReportPeriod.custom,
                          customStart: picked.start,
                          customEnd: picked.end,
                        ),
                      );
                    }
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Consumer(
              builder: (context, ref, child) {
                final currentFilters = ref.watch(reportFiltersProvider);
                final selectedIds = currentFilters.accountIds;
                final accountIdSet = activeAccounts.map((a) => a.id).toSet();

                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 4),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Row(
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
                                ref.read(reportFiltersProvider.notifier).update(
                                  (state) {
                                    final updated = state.accountIds
                                        .where(
                                          (id) => !accountIdSet.contains(id),
                                        )
                                        .toList();
                                    return state.copyWith(accountIds: updated);
                                  },
                                );
                              },
                              child: const Text('Limpar'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                        child: AppButton(
                          label: 'APLICAR',
                          expanded: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCreditCardFilter(BuildContext context, WidgetRef ref) {
    final creditCards = ref.read(creditCardsStreamProvider).value ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Consumer(
              builder: (context, ref, child) {
                final currentFilters = ref.watch(reportFiltersProvider);
                final selectedIds = currentFilters.creditCardIds;
                final cardIdSet = creditCards.map((c) => c.id).toSet();

                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 4),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Row(
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
                                ref.read(reportFiltersProvider.notifier).update(
                                  (state) {
                                    final updated = state.creditCardIds
                                        .where((id) => !cardIdSet.contains(id))
                                        .toList();
                                    return state.copyWith(
                                      creditCardIds: updated,
                                    );
                                  },
                                );
                              },
                              child: const Text('Limpar'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
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
                                onTap: () => _toggleCreditCard(ref, card.id),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                        child: AppButton(
                          label: 'APLICAR',
                          expanded: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _toggleAccount(WidgetRef ref, String id) {
    ref.read(reportFiltersProvider.notifier).update((state) {
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
    ref.read(reportFiltersProvider.notifier).update((state) {
      final current = List<String>.from(state.creditCardIds);
      if (current.contains(id)) {
        current.remove(id);
      } else {
        current.add(id);
      }
      return state.copyWith(creditCardIds: current);
    });
  }

  void _showTypeFilter(BuildContext context, WidgetRef ref) {
    final filters = ref.read(reportFiltersProvider);
    final notifier = ref.read(reportFiltersProvider.notifier);

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
                    notifier.update((f) => f.copyWith(clearType: true));
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
                      notifier.update((f) => f.copyWith(type: type.name));
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

  void _showCategoryFilter(BuildContext context, WidgetRef ref) {
    final filters = ref.read(reportFiltersProvider);
    final notifier = ref.read(reportFiltersProvider.notifier);
    final categories = ref.read(allFlatCategoriesProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Filtrar por Categoria',
                        style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            ListTile(
                              title: const Text('Todas as Categorias'),
                              leading: const Icon(Icons.category_outlined),
                              selected: filters.categoryId == null,
                              onTap: () {
                                notifier.update(
                                  (f) => f.copyWith(clearCategory: true),
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
                                  notifier.update(
                                    (f) => f.copyWith(categoryId: category.id),
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
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(reportFiltersProvider);
    final accounts = ref.watch(activeAccountsProvider);
    final creditCards = ref.watch(creditCardsStreamProvider).value ?? [];
    final categories = ref.watch(allFlatCategoriesProvider);

    String periodLabel;
    switch (filters.period) {
      case ReportPeriod.month:
        periodLabel = 'Mês';
      case ReportPeriod.quarter:
        periodLabel = 'Trimestre';
      case ReportPeriod.year:
        periodLabel = 'Ano';
      case ReportPeriod.custom:
        if (filters.customStart != null && filters.customEnd != null) {
          periodLabel =
              '${DateFormatter.formatDate(filters.customStart!)} - ${DateFormatter.formatDate(filters.customEnd!)}';
        } else {
          periodLabel = 'Personalizado';
        }
    }

    final selectedAccountIds = filters.accountIds
        .where((id) => accounts.any((a) => a.id == id))
        .toList();
    String accountLabel = 'Contas';
    if (selectedAccountIds.length == 1) {
      final acc = accounts
          .where((a) => a.id == selectedAccountIds.first)
          .firstOrNull;
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

    String typeLabel = 'Tipo';
    if (filters.type != null) {
      typeLabel = TransactionType.fromString(filters.type!).label;
    }

    String categoryLabel = 'Categoria';
    if (filters.categoryId != null && categories.isNotEmpty) {
      final cat = categories.firstWhere(
        (c) => c.id == filters.categoryId,
        orElse: () => categories.first,
      );
      categoryLabel = cat.name;
    }

    final hasExtraFilters =
        filters.accountIds.isNotEmpty ||
        filters.creditCardIds.isNotEmpty ||
        filters.type != null ||
        filters.categoryId != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          AnimatedChip(
            label: periodLabel,
            icon: Icons.calendar_month_outlined,
            selected: filters.period != ReportPeriod.month,
            onTap: () => _showPeriodFilter(context, ref),
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
            label: typeLabel,
            icon: Icons.filter_alt_outlined,
            selected: filters.type != null,
            onTap: () => _showTypeFilter(context, ref),
            delay: const Duration(milliseconds: 150),
          ),
          const SizedBox(width: 8),
          AnimatedChip(
            label: categoryLabel,
            icon: Icons.category_outlined,
            selected: filters.categoryId != null,
            onTap: () => _showCategoryFilter(context, ref),
            delay: const Duration(milliseconds: 200),
          ),
          if (hasExtraFilters) ...[
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Limpar filtros',
              onPressed: () {
                ref
                    .read(reportFiltersProvider.notifier)
                    .update(
                      (f) => f.copyWith(
                        clearAccounts: true,
                        clearCreditCards: true,
                        clearType: true,
                        clearCategory: true,
                      ),
                    );
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
