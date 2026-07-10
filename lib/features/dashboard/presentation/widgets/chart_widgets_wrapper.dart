import 'package:flutter/material.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/features/dashboard/domain/models/dashboard_data.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/features/reports/presentation/widgets/bar_chart_widget.dart';
import 'package:bestfin/features/reports/presentation/widgets/line_chart_widget.dart';

class MonthlyBarChartWidgetWrapper extends StatelessWidget {
  final List<MonthlyBar> bars;

  const MonthlyBarChartWidgetWrapper({super.key, required this.bars});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final hasData = bars.isNotEmpty;

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HISTÓRICO MENSAL',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      size: 64,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sem histórico mensal registrado.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            MonthlyBarChartWidget(bars: bars),
        ],
      ),
    );
  }
}

class CategoryRankingWidgetWrapper extends StatelessWidget {
  final List<CategoryRankingItem> items;

  const CategoryRankingWidgetWrapper({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final hasData = items.isNotEmpty;

    final maxAmount = items.fold<int>(
      0,
      (max, item) => item.amountInCents > max ? item.amountInCents : max,
    );

    final chartItems = items.map((item) {
      Color color;
      if (item.category != null && item.category!.color.isNotEmpty) {
        try {
          final hex = item.category!.color.replaceFirst('#', '');
          final buffer = StringBuffer();
          if (hex.length == 6) buffer.write('ff');
          buffer.write(hex);
          color = Color(int.parse(buffer.toString(), radix: 16));
        } catch (_) {
          color = cs.primary;
        }
      } else {
        color = cs.primary;
      }
      return (
        label: item.category?.name ?? 'Sem categoria',
        amount: item.amountInCents,
        color: color,
      );
    }).toList();

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RANKING DE CATEGORIAS',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.sort_rounded,
                      size: 64,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sem gastos por categoria este mês.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            CategoryBarChartWidget(items: chartItems, maxAmount: maxAmount),
        ],
      ),
    );
  }
}

class NetWorthLineChartWidgetWrapper extends StatelessWidget {
  final List<NetWorthPoint> points;

  const NetWorthLineChartWidgetWrapper({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final hasData = points.isNotEmpty;

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EVOLUÇÃO PATRIMONIAL',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 64,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum dado patrimonial disponível.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            NetWorthLineChartWidget(points: points),
        ],
      ),
    );
  }
}

class CashFlowLineChartWidgetWrapper extends StatelessWidget {
  final List<CashFlowPoint> points;

  const CashFlowLineChartWidgetWrapper({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final hasData = points.isNotEmpty;

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FLUXO DE CAIXA',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 64,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sem dados de fluxo de caixa registrados.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            CashFlowLineChartWidget(points: points),
        ],
      ),
    );
  }
}
