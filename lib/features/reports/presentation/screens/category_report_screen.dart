import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/reports/presentation/providers/reports_provider.dart';
import 'package:bestfin/features/reports/presentation/widgets/donut_chart_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/bar_chart_widget.dart';
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
        label: item.category?.name ?? 'Sem categoria',
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
        // Total card
        Card(
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Donut chart
        Card(
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
