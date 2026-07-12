import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/budgets/domain/models/budget_model.dart';
import 'package:bestfin/features/budgets/presentation/providers/budgets_provider.dart';
import 'package:bestfin/features/budgets/presentation/widgets/budget_card.dart';
import 'package:bestfin/features/budgets/presentation/widgets/budget_form_sheet.dart';

class BudgetsListScreen extends ConsumerStatefulWidget {
  const BudgetsListScreen({super.key});

  @override
  ConsumerState<BudgetsListScreen> createState() => _BudgetsListScreenState();
}

class _BudgetsListScreenState extends ConsumerState<BudgetsListScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
  }

  Future<void> _applyRollover() async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aplicar rollover'),
        content: Text(
          'Transferir saldo disponível de $_month/$_year para o próximo mês?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(applyRolloverProvider)(_year, _month);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rollover aplicado com sucesso!')),
        );
      }
    }
  }

  Future<void> _deleteBudget(BudgetModel budget) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir orçamento'),
        content: Text(
          'Remover o orçamento "${budget.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          AppButton(
            label: 'Excluir',
            variant: AppButtonVariant.destructive,
            size: AppButtonSize.compact,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(deleteBudgetProvider)(budget.id);
    }
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return '${months[month - 1]} $_year';
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final budgetsAsync = ref.watch(budgetsForPeriodProvider((_year, _month)));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Orçamento',
        infoDescription: 'Defina orçamentos mensais por categoria. Acompanhe seus gastos e mantenha o controle financeiro.',
        infoFeatures: [
          'Orçamento por categoria',
          'Rollover de saldo entre meses',
          'Acompanhamento de gastos em tempo real',
          'Alertas de estouro de orçamento',
        ],
        actions: [
          IconButton(
            icon: const Icon(Icons.autorenew_rounded),
            tooltip: 'Aplicar rollover',
            onPressed: _applyRollover,
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Novo orçamento',
            onPressed: () =>
                showBudgetFormSheet(context, year: _year, month: _month),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _prevMonth,
                ),
                Text(
                  _monthLabel(_month),
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          Expanded(
            child: budgetsAsync.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Erro: $err',
                  style: tt.bodyMedium?.copyWith(color: cs.error),
                ),
              ),
              data: (budgets) {
                if (budgets.isEmpty) {
                  return _EmptyState(
                    year: _year,
                    month: _month,
                    onAdd: () => showBudgetFormSheet(
                      context,
                      year: _year,
                      month: _month,
                    ),
                  );
                }

                final totalBudget = budgets.fold<int>(
                  0,
                  (sum, b) => sum + b.totalBudget,
                );
                final totalSpent = budgets.fold<int>(
                  0,
                  (sum, b) => sum + b.spent,
                );
                final overBudget = budgets.where((b) => b.isOverBudget).length;

                return Column(
                  children: [
                    _SummaryBar(
                      totalBudget: totalBudget,
                      totalSpent: totalSpent,
                      overBudget: overBudget,
                      cs: cs,
                      tt: tt,
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 100),
                        itemCount: budgets.length,
                        itemBuilder: (_, index) {
                          final b = budgets[index];
                          return BudgetCard(
                            budget: b,
                            onEdit: () => showBudgetFormSheet(
                              context,
                              existing: b,
                              year: _year,
                              month: _month,
                            ),
                            onDelete: () => _deleteBudget(b),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int totalBudget;
  final int totalSpent;
  final int overBudget;
  final ColorScheme cs;
  final TextTheme tt;

  const _SummaryBar({
    required this.totalBudget,
    required this.totalSpent,
    required this.overBudget,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final available = totalBudget - totalSpent;
    final progress = totalBudget == 0
        ? 0.0
        : (totalSpent / totalBudget).clamp(0.0, 1.0);
    final progressColor = overBudget > 0
        ? cs.error
        : (progress >= 0.75 ? context.customColors.warning : cs.primary);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gasto total',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    'R\$ ${(totalSpent / 100).toStringAsFixed(2)}',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: progressColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Disponível',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    'R\$ ${(available / 100).toStringAsFixed(2)}',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: available >= 0
                          ? context.customColors.income
                          : cs.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          if (overBudget > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$overBudget orçamento(s) acima do limite',
              style: tt.labelSmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int year;
  final int month;
  final VoidCallback onAdd;

  const _EmptyState({
    required this.year,
    required this.month,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum orçamento criado',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crie orçamentos para planejar seus gastos por categoria.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar primeiro orçamento'),
            ),
          ],
        ),
      ),
    );
  }
}
