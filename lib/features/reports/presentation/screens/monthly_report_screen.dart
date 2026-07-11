import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/reports/presentation/providers/reports_provider.dart';
import 'package:bestfin/features/reports/presentation/widgets/bar_chart_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/waterfall_chart_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/comparison_indicator.dart';
import 'package:bestfin/features/reports/presentation/widgets/report_card_pair.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';

class MonthlyReportScreen extends ConsumerWidget {
  const MonthlyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(valuesHiddenProvider);
    final reportAsync = ref.watch(monthlyReportProvider);

    return reportAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (report) {
        if (report.bars.isEmpty) {
          return const _EmptyState();
        }
        return _MonthlyReportContent(report: report);
      },
    );
  }
}

class _MonthlyReportContent extends StatelessWidget {
  final MonthlyReport report;

  const _MonthlyReportContent({required this.report});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final bars = report.bars;
    final currentBar = bars.isNotEmpty ? bars.last : null;
    final prevBar = bars.length >= 2 ? bars[bars.length - 2] : null;

    double incomeChange = 0;
    double expenseChange = 0;
    if (prevBar != null && currentBar != null) {
      incomeChange = prevBar.income > 0
          ? ((currentBar.income - prevBar.income) / prevBar.income) * 100
          : 0;
      expenseChange = prevBar.expense > 0
          ? ((currentBar.expense - prevBar.expense) / prevBar.expense) * 100
          : 0;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        if (currentBar != null) ...[
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 16,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Receitas',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatCents(currentBar.income),
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ComparisonIndicator(
                          changePercent: incomeChange,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              size: 16,
                              color: cs.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Despesas',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatCents(currentBar.expense),
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ComparisonIndicator(
                          changePercent: expenseChange,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Bar chart + Waterfall lado a lado em telas expandidas
        ReportCardPair(
          first: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receita vs Despesa', style: tt.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Legend(color: cs.primary, label: 'Receita'),
                      const SizedBox(width: 12),
                      _Legend(color: cs.error, label: 'Despesa'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MonthlyBarChartWidget(bars: bars),
                ],
              ),
            ),
          ),
          second: currentBar != null
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balanço do Mês (${currentBar.label})',
                          style: tt.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        WaterfallChartWidget(
                          income: currentBar.income,
                          expense: currentBar.expense,
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 64, color: cs.outlineVariant),
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
