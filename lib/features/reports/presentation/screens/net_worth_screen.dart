import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/reports/presentation/providers/reports_provider.dart';
import 'package:bestfin/features/reports/presentation/widgets/line_chart_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/comparison_indicator.dart';
import 'package:bestfin/features/reports/presentation/widgets/report_card_pair.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';

class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(valuesHiddenProvider);
    final reportAsync = ref.watch(netWorthProvider);

    return reportAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (report) => _NetWorthContent(report: report),
    );
  }
}

class _NetWorthContent extends StatelessWidget {
  final NetWorthReport report;

  const _NetWorthContent({required this.report});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero card + Line chart lado a lado em telas expandidas
        ReportCardPair(
          first: Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patrimônio Líquido',
                    style: tt.labelLarge?.copyWith(color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.formatCents(report.currentNetWorth),
                    style: tt.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ComparisonIndicator(changePercent: report.changePercent),
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
                  Text('Evolução do patrimônio', style: tt.titleMedium),
                  const SizedBox(height: 16),
                  NetWorthLineChartWidget(points: report.points),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Monthly breakdown
        if (report.points.length >= 2)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Histórico mensal', style: tt.titleMedium),
                  const SizedBox(height: 12),
                  for (final item in List.generate(report.points.length, (i) {
                    final p = report.points[i];
                    final prev = i > 0 ? report.points[i - 1] : null;
                    final change = prev != null && prev.netWorth != 0
                        ? ((p.netWorth - prev.netWorth) / prev.netWorth.abs()) *
                              100
                        : 0.0;
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
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${months[p.date.month - 1]} ${p.date.year}',
                              style: tt.labelSmall,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              CurrencyFormatter.formatCents(p.netWorth),
                              style: tt.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: p.netWorth < 0 ? cs.error : cs.onSurface,
                              ),
                            ),
                          ),
                          if (prev != null)
                            ComparisonIndicator(
                              changePercent: change,
                              compact: true,
                            ),
                        ],
                      ),
                    );
                  }).reversed)
                    item,
                ],
              ),
            ),
          ),
      ],
    );
  }
}
