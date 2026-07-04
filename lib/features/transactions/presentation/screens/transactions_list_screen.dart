import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/core/widgets/amount_display.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/utils/date_formatter.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transaction_form_modal_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_filters.dart';
import 'package:bestfin/features/transactions/presentation/widgets/delete_transaction_sheet.dart';

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
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final colors = context.customColors;
    ref.watch(valuesHiddenProvider);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final filters = ref.watch(transactionFiltersProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(
        title: 'Transações',
        showVisibilityToggle: true,
      ),
      body: Column(
        children: [
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
                            if (Breakpoints.isCompact(context)) {
                              context.push('/transaction/new');
                            } else {
                              ref
                                  .read(transactionFormModalProvider.notifier)
                                  .open();
                            }
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

                  final grouped = _groupTransactionsByDay(transactions);
                  final sortedDates = grouped.keys.toList();
                  final List<Object> flatList = [];
                  for (final dateKey in sortedDates) {
                    flatList.add(dateKey);
                    flatList.addAll(grouped[dateKey]!);
                  }

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
                      // Resumo consolidado do período
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            elevation: 0,
                            color: cs.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius: shapes.card,
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
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.arrow_downward_rounded,
                                                size: 12,
                                                color: colors.income,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Receitas',
                                                style: tt.labelMedium?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          AmountDisplay(
                                            amountInCents: totalIncomes,
                                            color: colors.income,
                                            style: tt.titleMedium?.copyWith(
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
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.arrow_upward_rounded,
                                                size: 12,
                                                color: colors.expense,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Despesas',
                                                style: tt.labelMedium?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          AmountDisplay(
                                            amountInCents: totalExpenses,
                                            color: colors.expense,
                                            style: tt.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            showSign: false,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Divider(
                                      height: 24,
                                      thickness: 1,
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Saldo do Período',
                                        style: tt.labelSmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      AmountDisplay(
                                        amountInCents:
                                            totalIncomes - totalExpenses,
                                        style: tt.titleMedium?.copyWith(
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
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = flatList[index];
                          if (item is String) {
                            final dateKey = item;
                            final txs = grouped[dateKey]!;
                            return _DayGroupHeader(
                              dateKey: dateKey,
                              transactions: txs,
                              dayNet: _calculateDayNet(txs),
                              cs: cs,
                              colors: colors,
                            );
                          } else {
                            final tx = item as TransactionModel;
                            return TransactionTile(
                              transaction: tx,
                              onTap: () {
                                if (Breakpoints.isCompact(context)) {
                                  context.push('/transaction/edit', extra: tx);
                                } else {
                                  ref
                                      .read(
                                        transactionFormModalProvider.notifier,
                                      )
                                      .open(transaction: tx);
                                }
                              },
                              onClone: () {
                                if (Breakpoints.isCompact(context)) {
                                  context.push(
                                    '/transaction/new?isCloning=true',
                                    extra: tx,
                                  );
                                } else {
                                  ref
                                      .read(
                                        transactionFormModalProvider.notifier,
                                      )
                                      .open(transaction: tx, isCloning: true);
                                }
                              },
                              onDelete: () =>
                                  showDeleteTransactionSheet(context, ref, tx),
                            );
                          }
                        }, childCount: flatList.length),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  );
                },
                loading: () => const Center(child: AppLoadingIndicator()),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: cs.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Erro ao carregar transações.',
                          textAlign: TextAlign.center,
                          style: tt.titleMedium?.copyWith(color: cs.error),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(filteredTransactionsProvider),
                          child: const Text('Tentar Novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayGroupHeader extends StatelessWidget {
  const _DayGroupHeader({
    required this.dateKey,
    required this.transactions,
    required this.dayNet,
    required this.cs,
    required this.colors,
  });

  final String dateKey;
  final List<TransactionModel> transactions;
  final int dayNet;
  final ColorScheme cs;
  final dynamic colors;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(transactions.first.date);
    final label = DateFormatter.formatRelativeDate(transactions.first.date);
    final isPositive = dayNet >= 0;
    final netColor = isPositive ? colors.income : colors.expense;
    final prefix = isPositive ? '+' : '−';
    final absNet = dayNet.abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isToday
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isToday ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ),
              Text(
                '$prefix${CurrencyFormatter.formatCents(absNet)}',
                style: AppTypography.monospace.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: netColor,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}
