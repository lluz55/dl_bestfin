import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/investments/presentation/providers/investments_provider.dart';
import 'package:bestfin/features/investments/presentation/providers/investment_form_modal_provider.dart';
import 'package:bestfin/features/investments/domain/models/investment.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';

class InvestmentDetailScreen extends ConsumerWidget {
  final String investmentId;

  const InvestmentDetailScreen({super.key, required this.investmentId});

  Future<void> _showUpdateYieldDialog(
    BuildContext context,
    WidgetRef ref,
    Investment inv,
  ) async {
    final repo = ref.read(investmentRepositoryProvider);
    final controller = TextEditingController();
    bool isProfit = inv.currentYield >= 0;
    int currentYieldCents = inv.currentYield.abs();

    final double yieldDouble = currentYieldCents / 100.0;
    controller.text = yieldDouble.toStringAsFixed(2).replaceAll('.', ',');

    void onCurrencyChanged(String value) {
      if (value.isEmpty) return;
      final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.isEmpty) return;
      currentYieldCents = int.parse(clean);
      final double amount = currentYieldCents / 100.0;
      final formatted = amount.toStringAsFixed(2).replaceAll('.', ',');

      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, setStfState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Atualizar Rendimento'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Informe o rendimento acumulado atual para este ativo.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ToggleButtons(
                        isSelected: [isProfit, !isProfit],
                        onPressed: (idx) {
                          setStfState(() {
                            isProfit = idx == 0;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        constraints: const BoxConstraints(
                          minHeight: 40,
                          minWidth: 50,
                        ),
                        selectedColor: isProfit
                            ? context.customColors.income
                            : context.customColors.expense,
                        fillColor: isProfit
                            ? context.customColors.income.withValues(alpha: 0.1)
                            : context.customColors.expense.withValues(alpha: 0.1),
                        children: const [
                          Text(
                            'Lucro',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Perda',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Rendimento',
                            prefixText: 'R\$ ',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: onCurrencyChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final finalYield = isProfit
                        ? currentYieldCents
                        : -currentYieldCents;
                    await repo.updateYield(inv.id, finalYield);
                    ref.invalidate(investmentsStreamProvider);
                    if (stfContext.mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rendimento atualizado!')),
                      );
                    }
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteInvestment(
    BuildContext context,
    WidgetRef ref,
    Investment inv,
  ) async {
    final repo = ref.read(investmentRepositoryProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Ativo?'),
        content: Text(
          'Tem certeza que deseja excluir o investimento "${inv.name}"? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          AppButton(
            label: 'Excluir',
            variant: AppButtonVariant.destructive,
            size: AppButtonSize.compact,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await repo.deleteInvestment(inv.id);
      ref.invalidate(investmentsStreamProvider);
      if (context.mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Investimento excluído com sucesso.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final custom = context.customColors;
    ref.watch(valuesHiddenProvider);

    final investmentAsync = ref.watch(investmentByIdProvider(investmentId));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Detalhes do Ativo',
        showVisibilityToggle: true,
        infoDescription: 'Visualize todos os detalhes do investimento: valor aplicado, rentabilidade, histórico de cotações e composição.',
        infoFeatures: const [
          'Valor atual e rentabilidade',
          'Histórico de cotações em gráfico',
          'Quantidade e valor médio',
          'Editar ou excluir ativo',
        ],
        actions: [
          investmentAsync.when(
            data: (inv) => IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              onPressed: () => ref
                  .read(investmentFormModalProvider.notifier)
                  .open(investment: inv),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          investmentAsync.when(
            data: (inv) => IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: cs.error,
              onPressed: () => _deleteInvestment(context, ref, inv),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: investmentAsync.when(
        data: (inv) {
          final double investedAmt = inv.investedAmount / 100.0;
          final double currentVal = inv.totalValue / 100.0;
          final double yieldAmt = inv.currentYield / 100.0;
          final double yieldPct = inv.yieldPercentage;
          final isPositive = inv.currentYield >= 0;

          final yieldColor = isPositive ? custom.income : custom.expense;
          final yieldSign = isPositive ? '+' : '';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header Card
              Card(
                color: cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        inv.name,
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          inv.typeLabel,
                          style: tt.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            label: 'Investido',
                            value:
                                'R\$ ${investedAmt.toStringAsFixed(2).replaceAll('.', ',')}',
                            tt: tt,
                          ),
                          _StatItem(
                            label: 'Valor Atual',
                            value:
                                'R\$ ${currentVal.toStringAsFixed(2).replaceAll('.', ',')}',
                            valueColor: cs.primary,
                            tt: tt,
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPositive
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            color: yieldColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rendimento: $yieldSign${yieldAmt.toStringAsFixed(2).replaceAll('.', ',')} ($yieldSign${yieldPct.toStringAsFixed(2)}%)',
                            style: tt.titleMedium
                                ?.copyWith(
                                  color: yieldColor,
                                  fontWeight: FontWeight.bold,
                                )
                                .merge(AppTypography.monospace),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Evolution Chart
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evolução do Ativo',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Comparativo entre valor aplicado e atual',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 650),
                          child: SizedBox(
                            height: 160,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: false),
                                titlesData: const FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: [
                                      FlSpot(0, investedAmt),
                                      FlSpot(1, currentVal),
                                    ],
                                    isCurved: false,
                                    color: cs.primary,
                                    barWidth: 4,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter:
                                          (spot, percent, barData, index) =>
                                              FlDotCirclePainter(
                                                radius: 6,
                                                color: cs.primary,
                                                strokeColor: cs.surface,
                                                strokeWidth: 2,
                                              ),
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: cs.primary.withValues(alpha: 0.08),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Inicial: R\$ ${investedAmt.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)
                                .merge(AppTypography.monospace),
                          ),
                          Text(
                            'Atual: R\$ ${currentVal.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: tt.bodySmall
                                ?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                )
                                .merge(AppTypography.monospace),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Maturity Details & Action Card
              Card(
                color: cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_note_rounded),
                        title: const Text('Vencimento'),
                        trailing: Text(
                          inv.maturityDate == null
                              ? 'Sem Vencimento'
                              : '${inv.maturityDate!.day.toString().padLeft(2, '0')}/${inv.maturityDate!.month.toString().padLeft(2, '0')}/${inv.maturityDate!.year}',
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 16),
                      const SizedBox(height: 8),
                      AppButton(
                        label: 'Atualizar Rendimento',
                        icon: Icons.price_change_outlined,
                        variant: AppButtonVariant.tonal,
                        expanded: true,
                        onPressed: () =>
                            _showUpdateYieldDialog(context, ref, inv),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final TextTheme tt;

  const _StatItem({
    required this.label,
    required this.value,
    this.valueColor,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: tt.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: valueColor)
              .merge(AppTypography.monospace),
        ),
      ],
    );
  }
}
