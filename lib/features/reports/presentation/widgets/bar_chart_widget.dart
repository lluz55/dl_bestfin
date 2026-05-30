import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

class MonthlyBarChartWidget extends StatefulWidget {
  final List<MonthlyBar> bars;

  const MonthlyBarChartWidget({super.key, required this.bars});

  @override
  State<MonthlyBarChartWidget> createState() => _MonthlyBarChartWidgetState();
}

class _MonthlyBarChartWidgetState extends State<MonthlyBarChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(MonthlyBarChartWidget old) {
    super.didUpdateWidget(old);
    if (old.bars != widget.bars) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.bars.isEmpty) {
      return const Center(child: Text('Nenhum dado disponível'));
    }

    final maxVal = widget.bars.fold<int>(
      0,
      (m, b) => [m, b.income, b.expense].reduce((a, b) => a > b ? a : b),
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return AspectRatio(
          aspectRatio: 1.7,
          child: BarChart(
            BarChartData(
              maxY: maxVal > 0 ? maxVal * 1.2 * _animation.value + 1 : 100,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final bar = widget.bars[group.x];
                    final label = rodIndex == 0 ? 'Receita' : 'Despesa';
                    final amt = rodIndex == 0 ? bar.income : bar.expense;
                    return BarTooltipItem(
                      '$label\n${CurrencyFormatter.formatCents(amt.toInt())}',
                      Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= widget.bars.length)
                        return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.bars[i].label,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.8,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      );
                    },
                    reservedSize: 32,
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVal > 0 ? maxVal / 4 : 25,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(widget.bars.length, (i) {
                final bar = widget.bars[i];
                return BarChartGroupData(
                  x: i,
                  barsSpace: 6,
                  barRods: [
                    BarChartRodData(
                      toY: bar.income.toDouble() * _animation.value,
                      color: cs.primary,
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                    BarChartRodData(
                      toY: bar.expense.toDouble() * _animation.value,
                      color: cs.error,
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

// Horizontal bar chart for category ranking
class CategoryBarChartWidget extends StatefulWidget {
  final List<({String label, int amount, Color color})> items;
  final int maxAmount;

  const CategoryBarChartWidget({
    super.key,
    required this.items,
    required this.maxAmount,
  });

  @override
  State<CategoryBarChartWidget> createState() => _CategoryBarChartWidgetState();
}

class _CategoryBarChartWidgetState extends State<CategoryBarChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Column(
          children: List.generate(widget.items.length, (i) {
            final item = widget.items[i];
            // stagger: each bar starts a bit later
            final staggerT = ((i * 0.05) < _animation.value)
                ? (_animation.value - i * 0.05).clamp(0.0, 1.0)
                : 0.0;
            final staggerRatio = widget.maxAmount > 0
                ? (item.amount / widget.maxAmount) * staggerT
                : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      item.label,
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: staggerRatio.clamp(0.0, 1.0),
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    child: Text(
                      CurrencyFormatter.formatCents(item.amount),
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}
