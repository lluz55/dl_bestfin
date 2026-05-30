import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
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
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const _filters = ['Este mês', 'Semana', '3 meses', 'Ano'];

  static String _getGreeting() {
    final now = DateTime.now();
    final months = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    final month = months[now.month - 1];
    if (now.hour < 12) return 'Bom dia, $month';
    if (now.hour < 18) return 'Boa tarde, $month';
    return 'Boa noite, $month';
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final visibleWidgets = ref.watch(homeWidgetsProvider);
    final hidden = ref.watch(valuesHiddenProvider);

    return Scaffold(
      backgroundColor: cs.surface,
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
            SliverPersistentHeader(
              pinned: true,
              delegate: _DashboardHeaderDelegate(
                cs: cs,
                tt: tt,
                greeting: _getGreeting(),
                hidden: hidden,
                onToggleHidden: () =>
                    ref.read(valuesHiddenProvider.notifier).toggle(),
                onTheme: () => showThemeSettingsSheet(context),
                onCustomize: () => showHomeWidgetsEditSheet(context),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer(
                    builder: (context, ref, child) {
                      final dashboardAsync = ref.watch(dashboardProvider);

                      return dashboardAsync.when(
                        data: (data) => Column(
                          children: [
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
                            const SizedBox(height: 100),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TransactionItem> _buildTransactionItems(dynamic data) {
    final accounts = ref.watch(activeAccountsProvider);
    return data.recentTransactions.map<TransactionItem>((tx) {
      final isExpense = tx.type == TransactionType.expense;
      final amountInCents = isExpense ? -tx.amount : tx.amount;

      final day = tx.date.day.toString().padLeft(2, '0');
      final month = tx.date.month.toString().padLeft(2, '0');
      final dateStr = '$day/$month';

      if (tx.type == TransactionType.transfer) {
        final fromAccount = accounts
            .where((a) => a.id == tx.fromAccountId)
            .firstOrNull;
        final toAccount = accounts
            .where((a) => a.id == tx.toAccountId)
            .firstOrNull;
        final fromName = fromAccount?.name ?? '—';
        final toName = toAccount?.name ?? '—';
        return TransactionItem(
          title: '$fromName → $toName',
          category: 'Transferência',
          amountInCents: amountInCents,
          date: dateStr,
          icon: Icons.swap_horiz_rounded,
          isCreditCard: tx.creditCardId != null,
          isRecurring: tx.recurringRuleId != null,
          rawTransaction: tx,
        );
      }

      return TransactionItem(
        title: tx.description,
        category: tx.category?.name ?? 'Sem Categoria',
        amountInCents: amountInCents,
        date: dateStr,
        icon: tx.category?.iconData ?? Icons.receipt_long_outlined,
        isCreditCard: tx.creditCardId != null,
        isRecurring: tx.recurringRuleId != null,
        rawTransaction: tx,
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
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final periodIndex = ref.watch(dashboardPeriodProvider);

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
      HomeWidgetId.periodFilter => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SectionHeader(title: 'Período', cs: cs, tt: tt),
            const SizedBox(height: 12),
            _QuickActionsRow(
              selectedIndex: periodIndex,
              onSelect: (i) =>
                  ref.read(dashboardPeriodProvider.notifier).select(i),
              filters: _filters,
            ),
          ],
        ),
      ),
      HomeWidgetId.quickActions => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
      ),
      HomeWidgetId.recentTransactions => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SectionHeader(
              title: 'Últimas transações',
              actionLabel: 'Ver todas',
              onAction: () => context.go('/transactions'),
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
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
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }
                return StaggeredTransactionList(
                  items: transactionItems,
                  onItemTap: (item) {
                    if (item.rawTransaction != null) {
                      context.push(
                        '/transaction/edit',
                        extra: item.rawTransaction,
                      );
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    };
  }
}

class _DashboardHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DashboardHeaderDelegate({
    required this.cs,
    required this.tt,
    required this.greeting,
    required this.hidden,
    required this.onToggleHidden,
    required this.onTheme,
    required this.onCustomize,
  });

  final ColorScheme cs;
  final TextTheme tt;
  final String greeting;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onTheme;
  final VoidCallback onCustomize;

  @override
  double get maxExtent => 96.0;

  @override
  double get minExtent => 56.0;

  @override
  bool shouldRebuild(_DashboardHeaderDelegate old) =>
      old.greeting != greeting || old.hidden != hidden || old.cs != cs;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final subtitleOpacity = (1.0 - t / 0.7).clamp(0.0, 1.0);
    final showDivider = t > 0.5;

    return Material(
      color: cs.surface,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BestFin',
                          style: TextStyle.lerp(
                            tt.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            t,
                          ),
                        ),
                        if (subtitleOpacity > 0.01)
                          Opacity(
                            opacity: subtitleOpacity,
                            child: Text(
                              greeting,
                              style: tt.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TonalIconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        hidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        key: ValueKey(hidden),
                        size: 18,
                      ),
                    ),
                    tooltip: hidden ? 'Mostrar valores' : 'Ocultar valores',
                    onPressed: onToggleHidden,
                    cs: cs,
                  ),
                  const SizedBox(width: 6),
                  _TonalIconButton(
                    icon: const Icon(Icons.palette_outlined, size: 18),
                    tooltip: 'Aparência',
                    onPressed: onTheme,
                    cs: cs,
                  ),
                  const SizedBox(width: 6),
                  _TonalIconButton(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    tooltip: 'Personalizar página inicial',
                    onPressed: onCustomize,
                    cs: cs,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 100),
            opacity: showDivider ? 1.0 : 0.0,
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TonalIconButton extends StatelessWidget {
  const _TonalIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.cs,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: icon),
        ),
      ),
    );
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: cs.primary,
                  ),
                ],
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
