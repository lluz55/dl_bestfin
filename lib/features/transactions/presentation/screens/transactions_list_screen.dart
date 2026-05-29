import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/core/widgets/amount_display.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/utils/date_formatter.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_filters.dart';

class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  Map<String, List<TransactionModel>> _groupTransactionsByDay(
    List<TransactionModel> list,
  ) {
    final Map<String, List<TransactionModel>> groups = {};
    for (final tx in list) {
      final dateKey = DateFormatter.formatDate(tx.date);
      groups.putIfAbsent(dateKey, () => []).add(tx);
    }
    return groups;
  }

  int _calculateDayNet(List<TransactionModel> list) {
    int net = 0;
    for (final tx in list) {
      if (tx.type == TransactionType.income) {
        net += tx.amount;
      } else if (tx.type == TransactionType.expense) {
        net -= tx.amount;
      }
    }
    return net;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final cs = context.colorScheme;
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final filters = ref.watch(transactionFiltersProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Transações'),
      body: Column(
        children: [
          // Row de filtros deslizantes
          const TransactionFiltersWidget(),
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(filteredTransactionsProvider);
              },
              child: transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Center(
                      child: EmptyState(
                        title: filters.isEmpty
                            ? 'Nenhuma Transação'
                            : 'Nenhum Resultado',
                        description: filters.isEmpty
                            ? 'Você ainda não registrou nenhuma despesa ou receita.'
                            : 'Nenhuma transação atende aos filtros selecionados.',
                        icon: Icons.swap_horiz_rounded,
                        actionLabel: filters.isEmpty
                            ? 'Nova Transação'
                            : 'Limpar Filtros',
                        onAction: () {
                          if (filters.isEmpty) {
                            context.push('/transaction/new');
                          } else {
                            ref
                                    .read(transactionFiltersProvider.notifier)
                                    .state =
                                const TransactionFilters();
                          }
                        },
                      ),
                    );
                  }

                  // Agrupa e renderiza
                  final grouped = _groupTransactionsByDay(transactions);
                  final sortedDates = grouped.keys.toList();

                  // Calcula receitas e despesas consolidadas do filtro
                  int totalIncomes = 0;
                  int totalExpenses = 0;
                  for (final tx in transactions) {
                    if (tx.type == TransactionType.income) {
                      totalIncomes += tx.amount;
                    } else if (tx.type == TransactionType.expense) {
                      totalExpenses += tx.amount;
                    }
                  }

                  return CustomScrollView(
                    slivers: [
                      // Resumo consolidado do período/filtros
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            elevation: 0,
                            color: cs.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Receitas',
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          AmountDisplay(
                                            amountInCents: totalIncomes,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  color: context
                                                      .customColors
                                                      .income,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            showSign: false,
                                          ),
                                        ],
                                      ),
                                      Container(
                                        height: 32,
                                        width: 1,
                                        color: cs.outlineVariant,
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Despesas',
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          AmountDisplay(
                                            amountInCents: totalExpenses,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  color: context
                                                      .customColors
                                                      .expense,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            showSign: false,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24, thickness: 0.5),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Saldo do Período',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: cs.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      AmountDisplay(
                                        amountInCents:
                                            totalIncomes - totalExpenses,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Listagem agrupada
                      for (final dateKey in sortedDates) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormatter.formatRelativeDate(
                                    grouped[dateKey]!.first.date,
                                  ),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatCents(
                                    _calculateDayNet(grouped[dateKey]!),
                                  ),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        _calculateDayNet(grouped[dateKey]!) >= 0
                                        ? context.customColors.income
                                        : context.customColors.expense,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final tx = grouped[dateKey]![index];
                            return TransactionTile(
                              transaction: tx,
                              onTap: () => context.push('/transaction/edit', extra: tx),
                              onClone: () => context.push(
                                '/transaction/new?isCloning=true',
                                extra: tx,
                              ),
                              onDelete: () async {
                                await ref.read(deleteTransactionProvider)(
                                  tx.id,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Transação excluída com sucesso.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            );
                          }, childCount: grouped[dateKey]!.length),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  );
                },
                loading: () => const Center(child: AppLoadingIndicator()),
                error: (err, stack) =>
                    Center(child: Text('Erro ao carregar transações: $err')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
