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
import 'package:bestfin/features/transactions/domain/models/transaction_group.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transaction_form_modal_provider.dart';
import 'package:bestfin/features/transactions/presentation/screens/transaction_group_screen.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:bestfin/features/transactions/presentation/widgets/grouped_transaction_tile.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_filters.dart';
import 'package:bestfin/features/transactions/presentation/widgets/delete_transaction_sheet.dart';
import 'package:bestfin/features/transactions/presentation/widgets/period_calendar_picker.dart';

class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState
    extends ConsumerState<TransactionsListScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

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

  void _enterSelection(List<String> ids) {
    setState(() {
      _selectionMode = true;
      _selectedIds.addAll(ids);
    });
  }

  /// Alterna a seleção de um lançamento (ou de todos os membros de um grupo).
  /// Sai do modo de seleção automaticamente quando nada fica selecionado.
  void _toggleSelection(List<String> ids) {
    setState(() {
      final allSelected = ids.every(_selectedIds.contains);
      if (allSelected) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<String> allIds) {
    setState(() {
      if (allIds.every(_selectedIds.contains)) {
        _selectedIds.clear();
        _selectionMode = false;
      } else {
        _selectedIds
          ..clear()
          ..addAll(allIds);
      }
    });
  }

  Future<void> _confirmDeleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final count = ids.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          count == 1 ? 'Excluir transação?' : 'Excluir $count transações?',
        ),
        content: const Text(
          'Esta ação não pode ser desfeita. Os saldos serão recalculados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(deleteTransactionsProvider).call(ids);
    if (!mounted) return;
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1 ? 'Transação excluída.' : '$count transações excluídas.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final colors = context.customColors;
    ref.watch(valuesHiddenProvider);
    final groupedDataAsync = ref.watch(groupedTransactionsProvider);
    final filters = ref.watch(transactionFiltersProvider);

    // Ids de todas as transações visíveis (membros de grupos incluídos) —
    // usados pelo "selecionar tudo" da barra de seleção.
    final allVisibleIds = <String>[
      for (final txs
          in groupedDataAsync.asData?.value.grouped.values ??
              const <List<TransactionModel>>[])
        for (final tx in txs) tx.id,
    ];

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: _selectionMode
            ? _buildSelectionAppBar(context, cs, tt, allVisibleIds)
            : const AppPageAppBar(
                title: 'Transações',
                showVisibilityToggle: true,
                infoDescription: 'Visualize, filtre e gerencie todas as suas transações financeiras. Use os filtros por período, tipo e categoria para encontrar rapidamente o que precisa.',
                infoFeatures: [
                  'Filtros por período, tipo e categoria',
                  'Modo de seleção múltipla para ações em lote',
                  'Visualização agrupada por dia',
                  'Toque longo para editar ou excluir',
                ],
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
                child: groupedDataAsync.when(
                  data: (groupedData) {
                    if (groupedData.flatList.isEmpty) {
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

                    final flatList = groupedData.flatList;
                    final grouped = groupedData.grouped;
                    final totalIncomes = groupedData.totalIncomes;
                    final totalExpenses = groupedData.totalExpenses;

                    // Em telas expandidas o resumo sai da rolagem e vira um
                    // painel lateral fixo; a lista ganha largura máxima.
                    final sidePanelLayout = Breakpoints.isExpanded(context);

                    final list = CustomScrollView(
                      slivers: [
                        // Resumo consolidado do período (inline no mobile)
                        if (!sidePanelLayout)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _PeriodSummaryCard(
                                totalIncomes: totalIncomes,
                                totalExpenses: totalExpenses,
                              ),
                            ),
                          ),

                        // Listagem agrupada
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final item = flatList[index];
                            if (item is String) {
                              final dateKey = item;
                              final txs = grouped[dateKey]!;
                              return InkWell(
                                onTap: () => PeriodCalendarPicker.show(context),
                                child: _DayGroupHeader(
                                  dateKey: dateKey,
                                  transactions: txs,
                                  dayNet: _calculateDayNet(txs),
                                  cs: cs,
                                  colors: colors,
                                ),
                              );
                            } else if (item is TransactionGroup) {
                              final memberIds = [
                                for (final m in item.members) m.id,
                              ];
                              return GroupedTransactionTile(
                                group: item,
                                selectionMode: _selectionMode,
                                selected: memberIds.every(
                                  _selectedIds.contains,
                                ),
                                onLongPress: () => _enterSelection(memberIds),
                                onTap: () {
                                  if (_selectionMode) {
                                    _toggleSelection(memberIds);
                                  } else {
                                    showTransactionGroupModal(
                                      context,
                                      item.groupId,
                                    );
                                  }
                                },
                              );
                            } else {
                              final tx = item as TransactionModel;
                              return TransactionTile(
                                transaction: tx,
                                selectionMode: _selectionMode,
                                selected: _selectedIds.contains(tx.id),
                                onLongPress: () => _enterSelection([tx.id]),
                                onTap: () {
                                  if (_selectionMode) {
                                    _toggleSelection([tx.id]);
                                    return;
                                  }
                                  if (Breakpoints.isCompact(context)) {
                                    context.push(
                                      '/transaction/edit',
                                      extra: tx,
                                    );
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
                                onDelete: () => showDeleteTransactionSheet(
                                  context,
                                  ref,
                                  tx,
                                ),
                                onMarkAsPaid: tx.isPending
                                    ? () => ref.read(
                                        markTransactionAsPaidProvider,
                                      )(tx.id)
                                    : null,
                              );
                            }
                          }, childCount: flatList.length),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    );

                    if (!sidePanelLayout) {
                      if (Breakpoints.isMedium(context)) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: list,
                          ),
                        );
                      }
                      return list;
                    }

                    // Resumo do período à esquerda; logo após, a lista de
                    // transações — tudo alinhado à esquerda.
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 340,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                            child: _PeriodSummaryCard(
                              totalIncomes: totalIncomes,
                              totalExpenses: totalExpenses,
                            ),
                          ),
                        ),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: list,
                          ),
                        ),
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
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    List<String> allVisibleIds,
  ) {
    final allSelected =
        allVisibleIds.isNotEmpty && allVisibleIds.every(_selectedIds.contains);
    return AppBar(
      backgroundColor: cs.surface,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Cancelar seleção',
        onPressed: _exitSelection,
      ),
      title: Text(
        '${_selectedIds.length} selecionada(s)',
        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          icon: Icon(
            allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
          ),
          tooltip: allSelected ? 'Limpar seleção' : 'Selecionar tudo',
          onPressed: allVisibleIds.isEmpty
              ? null
              : () => _selectAll(allVisibleIds),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Excluir selecionadas',
          color: cs.error,
          onPressed: _selectedIds.isEmpty ? null : _confirmDeleteSelected,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Resumo consolidado do período (Receitas | Despesas | Saldo).
///
/// Inline no topo da lista em telas compactas; painel lateral fixo em telas
/// expandidas.
class _PeriodSummaryCard extends StatelessWidget {
  const _PeriodSummaryCard({
    required this.totalIncomes,
    required this.totalExpenses,
  });

  final int totalIncomes;
  final int totalExpenses;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shapes = context.shapes;
    final colors = context.customColors;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: shapes.card),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                Container(height: 32, width: 1, color: cs.outlineVariant),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Divider(
                height: 24,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo do Período',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AmountDisplay(
                  amountInCents: totalIncomes - totalExpenses,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
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
