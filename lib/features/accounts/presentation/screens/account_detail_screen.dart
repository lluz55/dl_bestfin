import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/accounts/presentation/widgets/account_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/utils/date_formatter.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/transaction_group.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transaction_form_modal_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:bestfin/features/transactions/presentation/widgets/grouped_transaction_tile.dart';
import 'package:bestfin/features/transactions/presentation/widgets/delete_transaction_sheet.dart';
import 'package:bestfin/features/transactions/presentation/screens/transaction_group_screen.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Account account) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Excluir Conta'),
          content: Text(
            'Deseja realmente excluir "${account.name}"? '
            'Todas as transações vinculadas a essa conta também serão excluídas permanentemente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            AppButton(
              label: 'Confirmar',
              variant: AppButtonVariant.destructive,
              size: AppButtonSize.compact,
              onPressed: () async {
                Navigator.pop(dialogCtx);
                try {
                  final deleteUseCase = ref.read(deleteAccountProvider);
                  await deleteUseCase(account.id);

                  ref.invalidate(accountsProvider);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Operação realizada com sucesso.'),
                      ),
                    );
                    context.pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir conta: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
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
    ref.watch(valuesHiddenProvider);
    final accountAsync = ref.watch(accountByIdProvider(accountId));
    final groupedDataAsync = ref.watch(
      accountGroupedTransactionsProvider(accountId),
    );
    final chartSpotsAsync = ref.watch(
      accountBalanceEvolutionProvider(accountId),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageAppBar(
        title: 'Detalhes da Conta',
        showVisibilityToggle: true,
        actions: [
          accountAsync.when(
            data: (account) => MenuAnchor(
              builder: (context, controller, child) {
                return IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                );
              },
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push('/accounts/edit', extra: account),
                  child: const Text('Editar'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.fact_check_outlined),
                  onPressed: () =>
                      context.push('/accounts/$accountId/reconcile'),
                  child: const Text('Reconciliar'),
                ),
                MenuItemButton(
                  leadingIcon: Icon(
                    account.isActive
                        ? Icons.archive_outlined
                        : Icons.unarchive_outlined,
                  ),
                  onPressed: () async {
                    try {
                      final updateUseCase = ref.read(updateAccountProvider);
                      await updateUseCase(
                        id: account.id,
                        name: account.name,
                        type: account.type.name,
                        icon: account.icon,
                        color: account.color,
                        isActive: !account.isActive,
                      );

                      ref.invalidate(accountsProvider);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              account.isActive
                                  ? 'Conta inativada com sucesso.'
                                  : 'Conta reativada com sucesso.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao atualizar status: $e'),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(account.isActive ? 'Inativar' : 'Reativar'),
                ),
                MenuItemButton(
                  leadingIcon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () => _showDeleteDialog(context, ref, account),
                  child: Text(
                    'Excluir',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: accountAsync.when(
        data: (account) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: AccountCard(
                    account: account,
                    onTap: () {}, // Noop in detail screen
                  ),
                ),
              ),

              // Evolution Chart Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evolução do Saldo',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 180,
                            child: chartSpotsAsync.when(
                              data: (spots) {
                                if (spots.length < 2) {
                                  return Center(
                                    child: Text(
                                      'Registros insuficientes para exibir o gráfico.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  );
                                }

                                final accountColor = hexToColor(account.color);

                                return LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(show: false),
                                    titlesData: const FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    lineTouchData: LineTouchData(
                                      touchTooltipData: LineTouchTooltipData(
                                        getTooltipItems: (touchedSpots) {
                                          return touchedSpots.map((spot) {
                                            final val = spot.y;
                                            final formatted =
                                                CurrencyFormatter.valuesHidden
                                                ? 'R\$ •••••'
                                                : 'R\$ ${val.abs().toStringAsFixed(2).replaceAll('.', ',')}';
                                            return LineTooltipItem(
                                              formatted,
                                              theme.textTheme.bodySmall!
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots,
                                        isCurved: false,
                                        color: accountColor,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              accountColor.withValues(
                                                alpha: 0.3,
                                              ),
                                              accountColor.withValues(
                                                alpha: 0.0,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              loading: () =>
                                  const Center(child: AppLoadingIndicator()),
                              error: (err, _) =>
                                  Center(child: Text('Erro no gráfico: $err')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Transactions List Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Text(
                    'Extrato recente',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

              // Transactions list
              groupedDataAsync.when(
                data: (groupedData) {
                  if (groupedData.flatList.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: EmptyState(
                            title: 'Nenhuma Transação',
                            description:
                                'Esta conta ainda não possui movimentações.',
                            icon: Icons.receipt_long_outlined,
                          ),
                        ),
                      ),
                    );
                  }

                  final flatList = groupedData.flatList;
                  final grouped = groupedData.grouped;

                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = flatList[index];
                      if (item is String) {
                        final dateKey = item;
                        final txs = grouped[dateKey]!;
                        return _DayGroupHeader(
                          dateKey: dateKey,
                          transactions: txs,
                          dayNet: _calculateDayNet(txs),
                          cs: theme.colorScheme,
                          colors: context.customColors,
                        );
                      } else if (item is TransactionGroup) {
                        return GroupedTransactionTile(
                          group: item,
                          onTap: () {
                            showTransactionGroupModal(context, item.groupId);
                          },
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
                                  .read(transactionFormModalProvider.notifier)
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
                                  .read(transactionFormModalProvider.notifier)
                                  .open(transaction: tx, isCloning: true);
                            }
                          },
                          onDelete: () =>
                              showDeleteTransactionSheet(context, ref, tx),
                          onMarkAsPaid: tx.isPending
                              ? () => ref.read(markTransactionAsPaidProvider)(
                                  tx.id,
                                )
                              : null,
                        );
                      }
                    }, childCount: flatList.length),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: AppLoadingIndicator(),
                    ),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Text('Erro ao carregar transações: $err'),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (err, _) => Center(child: Text('Erro ao carregar conta: $err')),
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
