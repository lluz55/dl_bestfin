import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/reports/presentation/providers/reports_provider.dart';
import 'package:bestfin/features/reports/presentation/widgets/line_chart_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/report_card_pair.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';

class CashFlowScreen extends ConsumerWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(valuesHiddenProvider);
    final reportAsync = ref.watch(cashFlowProvider);

    return reportAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (report) {
        if (report.points.isEmpty) {
          return _emptyState(context);
        }
        return _CashFlowContent(report: report);
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    return const EmptyState(
      icon: Icons.show_chart,
      title: 'Nenhuma transação no período',
      description: 'Não há lançamentos registrados no período selecionado.',
    );
  }
}

class _CashFlowContent extends StatelessWidget {
  final CashFlowReport report;

  const _CashFlowContent({required this.report});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final net = report.totalIncome - report.totalExpense;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: 'Entradas',
                value: report.totalIncome,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                label: 'Saídas',
                value: report.totalExpense,
                color: cs.error,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                label: 'Líquido',
                value: net,
                color: net >= 0 ? cs.tertiary : cs.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ReportCardPair(
          first: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saldo acumulado', style: tt.titleMedium),
                  const SizedBox(height: 16),
                  CashFlowLineChartWidget(points: report.points),
                ],
              ),
            ),
          ),
          second: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Movimentações diárias', style: tt.titleMedium),
                  const SizedBox(height: 12),
                  ...report.points.map((p) {
                    final net = p.income - p.expense;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              '${p.date.day.toString().padLeft(2, '0')}/${p.date.month.toString().padLeft(2, '0')}',
                              style: tt.labelSmall,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '+ ${CurrencyFormatter.formatCents(p.income)}',
                              style: tt.labelSmall?.copyWith(color: cs.primary),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '- ${CurrencyFormatter.formatCents(p.expense)}',
                              style: tt.labelSmall?.copyWith(color: cs.error),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 90,
                            child: Text(
                              '${net >= 0 ? '+' : ''}${CurrencyFormatter.formatCents(net)}',
                              style: tt.labelSmall?.copyWith(
                                color: net >= 0 ? cs.tertiary : cs.error,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ), // ReportCardPair
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              CurrencyFormatter.formatCents(value),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
