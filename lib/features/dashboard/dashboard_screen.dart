import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/providers/user_profile_provider.dart';
import 'package:bestfin/core/providers/sidebar_provider.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/animated_chip.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/core/widgets/profile_avatar.dart';
import 'package:bestfin/core/widgets/staggered_transaction_list.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/features/transactions/presentation/providers/transaction_form_modal_provider.dart';
import 'package:bestfin/features/transactions/presentation/widgets/quick_transaction_sheet.dart';

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
import 'package:bestfin/features/dashboard/presentation/widgets/dashboard_grid.dart';
import 'package:bestfin/features/gamification/presentation/widgets/streaks_dashboard_widget.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/budgets/presentation/widgets/budgets_overview_card.dart';
import 'package:bestfin/features/cashflow/presentation/widgets/cashflow_projection_card.dart';
import 'package:bestfin/features/onboarding/presentation/providers/tutorial_provider.dart';
import 'package:bestfin/features/onboarding/presentation/widgets/tutorial_runner.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const _filters = ['Este mês', 'Semana', '3 meses', 'Ano'];

  final _customizeKey = GlobalKey(debugLabel: 'tutorial_customize');

  static String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  /// Demonstração prática do primeiro passo do tutorial: abre o fluxo real de
  /// nova transação (despesa) e retorna quando o modal é fechado.
  Future<void> _runTransactionDemo() {
    return showAdaptiveModal<void>(
      context: context,
      builder: (_) =>
          const QuickTransactionSheet(initialType: TransactionType.expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final visibleWidgets = ref.watch(homeWidgetsProvider);
    final hidden = ref.watch(valuesHiddenProvider);
    final tutorialKeys = ref.watch(tutorialKeysProvider);
    final profile = ref.watch(userProfileProvider);
    final syncState = ref.watch(syncStateProvider);
    final isSyncingBg =
        syncState.status == SyncStatus.syncing && syncState.isBackground;
    final syncIndicator = isSyncingBg
        ? _SyncIndicator.syncing
        : syncState.backgroundJustSucceeded
        ? _SyncIndicator.success
        : syncState.backgroundErrorMessage != null
        ? _SyncIndicator.error
        : _SyncIndicator.none;

    return TutorialRunner(
      fabKey: tutorialKeys.fabKey,
      transactionsTabKey: tutorialKeys.transactionsTabKey,
      reportsTabKey: tutorialKeys.reportsTabKey,
      maisTabKey: tutorialKeys.maisTabKey,
      customizeKey: _customizeKey,
      onCreateTransaction: _runTransactionDemo,
      child: Scaffold(
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
                  greeting: profile.firstName != null
                      ? '${_getGreeting()}, ${profile.firstName}'
                      : _getGreeting(),
                  profile: profile,
                  hidden: hidden,
                  syncIndicator: syncIndicator,
                  customizeKey: _customizeKey,
                  showHeaderIcon:
                      !Breakpoints.isExpanded(context) ||
                      ref.watch(sidebarCollapsedProvider),
                  onToggleHidden: () =>
                      ref.read(valuesHiddenProvider.notifier).toggle(),
                  onCustomize: () => showHomeWidgetsEditSheet(context),
                  onSyncErrorTap: syncState.backgroundErrorMessage == null
                      ? null
                      : () => _showSyncErrorDialog(
                          context,
                          syncState.backgroundErrorMessage!,
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Consumer(
                  builder: (context, ref, child) {
                    final dashboardAsync = ref.watch(dashboardProvider);

                    return dashboardAsync.when(
                      data: (data) => _buildResponsiveContent(
                        data: data,
                        visibleWidgets: visibleWidgets,
                        cs: cs,
                        tt: tt,
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: Center(child: AppLoadingIndicator()),
                      ),
                      error: (err, stack) => _buildError(err, cs, tt),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveContent({
    required dynamic data,
    required List<HomeWidgetId> visibleWidgets,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    if (Breakpoints.isCompact(context)) {
      return _buildCompactLayout(data, visibleWidgets, cs, tt);
    }
    return _buildMediumLayout(data, visibleWidgets, cs, tt);
  }

  Widget _buildCompactLayout(
    dynamic data,
    List<HomeWidgetId> visibleWidgets,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BalanceCard(
                balanceInCents: data.totalBalance,
                monthlyIncome: data.monthlyIncome,
                monthlyExpense: data.monthlyExpense,
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
          for (int i = 0; i < visibleWidgets.length; i++) ...[
            const SizedBox(height: 8),
            _buildWidget(visibleWidgets[i], data, i)
                .animate()
                .fadeIn(
                  duration: 400.ms,
                  delay: Duration(milliseconds: 150 + i * 50),
                )
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMediumLayout(
    dynamic data,
    List<HomeWidgetId> visibleWidgets,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          BalanceCard(
                balanceInCents: data.totalBalance,
                monthlyIncome: data.monthlyIncome,
                monthlyExpense: data.monthlyExpense,
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),
          DashboardGrid(
            children: [
              for (int i = 0; i < visibleWidgets.length; i++)
                _buildWidget(visibleWidgets[i], data, i)
                    .animate()
                    .fadeIn(
                      duration: 400.ms,
                      delay: Duration(milliseconds: 150 + i * 50),
                    )
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  List<TransactionItem> _buildTransactionItems(
    dynamic data,
    Map<dynamic, dynamic> accountsById,
  ) {
    return data.recentTransactions.map<TransactionItem>((tx) {
      final isExpense = tx.type == TransactionType.expense;
      final amountInCents = isExpense ? -tx.amount : tx.amount;

      final day = tx.date.day.toString().padLeft(2, '0');
      final month = tx.date.month.toString().padLeft(2, '0');
      final dateStr = '$day/$month';

      if (tx.type == TransactionType.transfer) {
        final fromName = accountsById[tx.fromAccountId]?.name ?? '—';
        final toName = accountsById[tx.toAccountId]?.name ?? '—';
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

  void _showSyncErrorDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Erro ao sincronizar'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/sync');
            },
            child: const Text('Ver sincronização'),
          ),
        ],
      ),
    );
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
              'Não foi possível carregar os dados. Tente novamente.',
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

    final widget = switch (id) {
      HomeWidgetId.freeToSpend => FreeToSpendCard(
        amountInCents: data.freeToSpendAmount,
        percentage: data.freeToSpendPercentage,
      ),
      HomeWidgetId.incomeExpenseBar => IncomeExpenseBar(
        monthlyIncome: data.monthlyIncome,
        monthlyExpense: data.monthlyExpense,
        periodLabel: _filters[periodIndex],
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
                showAdaptiveModal(
                  context: context,
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
            Consumer(
              builder: (context, ref, _) {
                final accounts = ref.watch(activeAccountsProvider);
                final accountsById = {for (final a in accounts) a.id: a};
                final transactionItems = _buildTransactionItems(
                  data,
                  accountsById,
                );
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
                      if (Breakpoints.isCompact(context)) {
                        context.push(
                          '/transaction/edit',
                          extra: item.rawTransaction,
                        );
                      } else {
                        ref
                            .read(transactionFormModalProvider.notifier)
                            .open(transaction: item.rawTransaction);
                      }
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
      HomeWidgetId.budgetsOverview => const BudgetsOverviewCard(),
      HomeWidgetId.cashFlowProjection => const CashFlowProjectionCard(),
    };

    return widget;
  }
}

enum _SyncIndicator { none, syncing, success, error }

class _DashboardHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DashboardHeaderDelegate({
    required this.cs,
    required this.tt,
    required this.greeting,
    required this.profile,
    required this.hidden,
    required this.syncIndicator,
    required this.onToggleHidden,
    required this.onCustomize,
    required this.showHeaderIcon,
    this.onSyncErrorTap,
    this.customizeKey,
  });

  final ColorScheme cs;
  final TextTheme tt;
  final String greeting;
  final UserProfile profile;
  final bool hidden;
  final _SyncIndicator syncIndicator;
  final VoidCallback onToggleHidden;
  final VoidCallback onCustomize;
  final VoidCallback? onSyncErrorTap;
  final GlobalKey? customizeKey;
  final bool showHeaderIcon;

  @override
  double get maxExtent => 96.0;

  @override
  double get minExtent => 56.0;

  @override
  bool shouldRebuild(_DashboardHeaderDelegate old) =>
      old.greeting != greeting ||
      old.profile.photoPath != profile.photoPath ||
      old.hidden != hidden ||
      old.syncIndicator != syncIndicator ||
      old.cs != cs ||
      old.showHeaderIcon != showHeaderIcon;

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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // A foto do usuário substitui o ícone do app e
                            // aparece mesmo quando a sidebar já mostra a
                            // marca (showHeaderIcon false) — é identidade do
                            // usuário, não branding.
                            if (profile.hasPhoto) ...[
                              ProfileAvatar(profile: profile, radius: 14),
                              const SizedBox(width: 8),
                            ] else if (showHeaderIcon) ...[
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [cs.primary, cs.secondary],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
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
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                              child: switch (syncIndicator) {
                                _SyncIndicator.syncing => Padding(
                                  key: const ValueKey('syncing'),
                                  padding: const EdgeInsets.only(left: 6),
                                  child:
                                      Icon(
                                            Icons.sync_rounded,
                                            size: 14,
                                            color: cs.primary.withValues(
                                              alpha: 0.7,
                                            ),
                                          )
                                          .animate(onPlay: (c) => c.repeat())
                                          .rotate(duration: 1200.ms),
                                ),
                                _SyncIndicator.success => Padding(
                                  key: const ValueKey('success'),
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 14,
                                    color: cs.primary,
                                  ),
                                ),
                                _SyncIndicator.error => Padding(
                                  key: const ValueKey('error'),
                                  padding: const EdgeInsets.only(left: 4),
                                  child: InkWell(
                                    onTap: onSyncErrorTap,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.error_outline_rounded,
                                        size: 14,
                                        color: cs.error,
                                      ),
                                    ),
                                  ),
                                ),
                                _SyncIndicator.none => const SizedBox.shrink(
                                  key: ValueKey('idle'),
                                ),
                              },
                            ),
                          ],
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
                    key: customizeKey,
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
    super.key,
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
                  child: Material(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => context.push(shortcut.route),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                              child: Icon(
                                shortcut.icon,
                                size: 20,
                                color: color,
                              ),
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
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(child: AppLoadingIndicator()),
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
  final ColorScheme cs;
  final TextTheme tt;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 2,
              height: 18,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
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
              ),
            ],
          ],
        ),
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
          delay: Duration(milliseconds: 200 + i.clamp(0, 4) * 60),
        ),
      ),
    );
  }
}
