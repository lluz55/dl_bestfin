import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/reports/presentation/providers/reports_provider.dart';
import 'package:bestfin/features/reports/presentation/widgets/donut_chart_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/bar_chart_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/report_card_pair.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';

class CategoryReportScreen extends ConsumerWidget {
  const CategoryReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(valuesHiddenProvider);
    final reportAsync = ref.watch(categoryReportProvider);

    return reportAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (report) {
        if (report.items.isEmpty) {
          return const _EmptyState(
            icon: Icons.pie_chart_outline,
            message: 'Nenhuma despesa no período',
          );
        }
        return _CategoryReportContent(report: report);
      },
    );
  }
}

class _CategoryReportContent extends StatelessWidget {
  final CategoryReport report;

  const _CategoryReportContent({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Build horizontal bar data from items
    final barItems = report.items.map((item) {
      Color color;
      try {
        color = item.category?.parsedColor ?? cs.primary;
      } catch (_) {
        color = cs.primary;
      }
      return (
        label: item.category?.displayName ?? 'Sem categoria',
        amount: item.amountInCents,
        color: color,
      );
    }).toList();

    final maxAmount = barItems.isEmpty
        ? 1
        : barItems.map((i) => i.amount).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ReportCardPair(
          first: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total gasto',
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.formatCents(report.totalExpense),
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.category_outlined,
                    label: 'Categorias',
                    value: '${report.items.length}',
                    tt: tt,
                    cs: cs,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.trending_flat_rounded,
                    label: 'Média por categoria',
                    value: CurrencyFormatter.formatCents(
                      report.totalExpense ~/ report.items.length,
                    ),
                    tt: tt,
                    cs: cs,
                  ),
                  if (report.items
                          .fold<int>(0, (s, e) => s + e.pendingAmountInCents) >
                      0) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.schedule_outlined,
                      label: 'Pendente',
                      value: CurrencyFormatter.formatCents(
                        report.items.fold<int>(
                          0,
                          (s, e) => s + e.pendingAmountInCents,
                        ),
                      ),
                      tt: tt,
                      cs: cs,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Período',
                    value:
                        '${report.startDate.day}/${report.startDate.month} — ${report.endDate.day}/${report.endDate.month}',
                    tt: tt,
                    cs: cs,
                  ),
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
                  Text('Gastos por categoria', style: tt.titleMedium),
                  const SizedBox(height: 16),
                  DonutChartWidget(
                    items: report.items,
                    totalInCents: report.totalExpense,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Horizontal bar ranking
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ranking de categorias', style: tt.titleMedium),
                const SizedBox(height: 16),
                CategoryBarChartWidget(items: barItems, maxAmount: maxAmount),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextTheme tt;
  final ColorScheme cs;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tt,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const Spacer(),
        Text(
          value,
          style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
