import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/reports/presentation/providers/reports_provider.dart';
import 'package:bestfin/features/reports/presentation/widgets/line_chart_widget.dart';

class CashFlowScreen extends ConsumerWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(cashFlowProvider);

    return reportAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Nenhuma transação no período',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
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
        Card(
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
        const SizedBox(height: 16),
        Card(
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
                          width: 80,
                          child: Text(
                            '${p.date.day.toString().padLeft(2, '0')}/${p.date.month.toString().padLeft(2, '0')}',
                            style: tt.labelSmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '+ R\$ ${(p.income / 100).toStringAsFixed(2)}',
                            style: tt.labelSmall?.copyWith(color: cs.primary),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '- R\$ ${(p.expense / 100).toStringAsFixed(2)}',
                            style: tt.labelSmall?.copyWith(color: cs.error),
                          ),
                        ),
                        Text(
                          '${net >= 0 ? '+' : ''}R\$ ${(net / 100).toStringAsFixed(2)}',
                          style: tt.labelSmall?.copyWith(
                            color: net >= 0 ? cs.tertiary : cs.error,
                            fontWeight: FontWeight.w600,
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
              'R\$ ${(value.abs() / 100).toStringAsFixed(0)}',
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
