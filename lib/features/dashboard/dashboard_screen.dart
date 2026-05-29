import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/theme/theme_settings_sheet.dart';
import 'package:bestfin/core/widgets/animated_chip.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/core/widgets/staggered_transaction_list.dart';
import 'package:bestfin/core/constants/transaction_types.dart';

import 'package:bestfin/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:bestfin/features/dashboard/presentation/providers/shortcuts_provider.dart';
import 'package:bestfin/features/dashboard/presentation/providers/home_widgets_provider.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/shortcuts_edit_sheet.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/home_widgets_edit_sheet.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/balance_card.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/free_to_spend_card.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/spending_donut.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/income_expense_bar.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/upcoming_bills.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/goals_progress.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/insight_card.dart';
import 'package:bestfin/features/dashboard/presentation/widgets/chart_widgets_wrapper.dart';
import 'package:bestfin/features/gamification/presentation/widgets/streaks_dashboard_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const _filters = ['Este mês', 'Semana', '3 meses', 'Ano'];

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final visibleWidgets = ref.watch(homeWidgetsProvider);
    final periodIndex = ref.watch(dashboardPeriodProvider);
    final hidden = ref.watch(valuesHiddenProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'BestFin',
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                key: ValueKey(hidden),
              ),
            ),
            tooltip: hidden ? 'Mostrar valores' : 'Ocultar valores',
            onPressed: () => ref.read(valuesHiddenProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Aparência',
            onPressed: () => showThemeSettingsSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Personalizar página inicial',
            onPressed: () => showHomeWidgetsEditSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        },
        color: cs.primary,
        backgroundColor: cs.surfaceContainerHighest,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Widgets que dependem do DashboardData
                  Consumer(
                    builder: (context, ref, child) {
                      final dashboardAsync = ref.watch(dashboardProvider);

                      return dashboardAsync.when(
                        data: (data) => Column(
                          children: [
                            // Balance Card
                            BalanceCard(
                                  balanceInCents: data.totalBalance,
                                  monthlyIncome: data.monthlyIncome,
                                  monthlyExpense: data.monthlyExpense,
                                )
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 100.ms)
                                .slideY(
                                  begin: 0.1,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                ),

                            // Widgets dinâmicos
                            for (int i = 0; i < visibleWidgets.length; i++) ...[
                              const SizedBox(height: 8),
                              _buildWidget(visibleWidgets[i], data, i)
                                  .animate()
                                  .fadeIn(
                                    duration: 400.ms,
                                    delay: Duration(milliseconds: 150 + i * 50),
                                  )
                                  .slideY(
                                    begin: 0.1,
                                    end: 0,
                                    curve: Curves.easeOutCubic,
                                  ),
                            ],
                          ],
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 64),
                          child: Center(child: AppLoadingIndicator()),
                        ),
                        error: (err, stack) => _buildError(err, cs, tt),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  _SectionHeader(title: 'Período', cs: cs, tt: tt),
                  const SizedBox(height: 12),
                  _QuickActionsRow(
                    selectedIndex: periodIndex,
                    onSelect: (i) =>
                        ref.read(dashboardPeriodProvider.notifier).select(i),
                    filters: _filters,
                  ),
                  const SizedBox(height: 24),

                  _SectionHeader(
                    title: 'Ações rápidas',
                    actionLabel: 'Editar',
                    onAction: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const ShortcutsEditSheet(),
                      );
                    },
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(height: 12),
                  const _ShortcutsRow(),
                  const SizedBox(height: 24),

                  _SectionHeader(
                    title: 'Últimas transações',
                    actionLabel: 'Ver todas',
                    onAction: () => context.push('/transactions'),
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(height: 8),

                  Consumer(
                    builder: (context, ref, child) {
                      final dashboardAsync = ref.watch(dashboardProvider);
                      return dashboardAsync.when(
                        data: (data) {
                          final transactionItems = _buildTransactionItems(data);
                          if (transactionItems.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                                horizontal: 20,
                              ),
                              child: Center(
                                child: Text(
                                  'Nenhuma transação recente encontrada.',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return StaggeredTransactionList(
                            items: transactionItems,
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (err, stack) => const SizedBox.shrink(),
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TransactionItem> _buildTransactionItems(dynamic data) {
    return data.recentTransactions.map<TransactionItem>((tx) {
      final isExpense = tx.type == TransactionType.expense;
      final amountInCents = isExpense ? -tx.amount : tx.amount;

      final day = tx.date.day.toString().padLeft(2, '0');
      final month = tx.date.month.toString().padLeft(2, '0');
      final dateStr = '$day/$month';

      return TransactionItem(
        title: tx.description,
        category: tx.category?.name ?? 'Sem Categoria',
        amountInCents: amountInCents,
        date: dateStr,
        icon: tx.category?.iconData ?? Icons.receipt_long_outlined,
      );
    }).toList();
  }

  Widget _buildError(Object err, ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar os dados do Dashboard.',
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(color: cs.error),
            ),
            const SizedBox(height: 8),
            Text(
              err.toString(),
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(dashboardProvider),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWidget(HomeWidgetId id, dynamic data, int index) {
    return switch (id) {
      HomeWidgetId.freeToSpend => FreeToSpendCard(
        amountInCents: data.freeToSpendAmount,
        percentage: data.freeToSpendPercentage,
      ),
      HomeWidgetId.incomeExpenseBar => IncomeExpenseBar(
        monthlyIncome: data.monthlyIncome,
        monthlyExpense: data.monthlyExpense,
      ),
      HomeWidgetId.spendingDonut => SpendingDonut(
        categoryExpenses: data.categoryExpenses,
      ),
      HomeWidgetId.goalsProgress => GoalsProgress(goals: data.activeGoals),
      HomeWidgetId.upcomingBills => UpcomingBills(
        transactions: data.upcomingTransactions,
      ),
      HomeWidgetId.streaks => const StreaksDashboardWidget(),
      HomeWidgetId.insightCard => const InsightCard(),
      HomeWidgetId.monthlyBarChart => MonthlyBarChartWidgetWrapper(
        bars: data.monthlyHistory,
      ),
      HomeWidgetId.netWorthLineChart => NetWorthLineChartWidgetWrapper(
        points: data.netWorthHistory,
      ),
      HomeWidgetId.categoryRanking => CategoryRankingWidgetWrapper(
        items: data.categoryRanking,
      ),
      HomeWidgetId.cashFlowLineChart => CashFlowLineChartWidgetWrapper(
        points: data.cashFlowHistory,
      ),
    };
  }
}

class _ShortcutsRow extends ConsumerWidget {
  const _ShortcutsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final shortcutsAsync = ref.watch(shortcutsProvider);

    return shortcutsAsync.when(
      data: (shortcuts) {
        if (shortcuts.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: shortcuts.map((shortcut) {
              final color = shortcut.getColor(cs);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => context.push(shortcut.route),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(shortcut.icon, size: 20, color: color),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            shortcut.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}


class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.cs,
    required this.tt,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: tt.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.selectedIndex,
    required this.onSelect,
    required this.filters,
  });

  final int selectedIndex;
  final void Function(int) onSelect;
  final List<String> filters;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) => AnimatedChip(
          label: filters[i],
          selected: selectedIndex == i,
          onTap: () => onSelect(i),
          delay: Duration(milliseconds: 200 + i * 60),
        ),
      ),
    );
  }
}
