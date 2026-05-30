import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

class WaterfallChartWidget extends StatefulWidget {
  final int income;
  final int expense;

  const WaterfallChartWidget({
    super.key,
    required this.income,
    required this.expense,
  });

  @override
  State<WaterfallChartWidget> createState() => _WaterfallChartWidgetState();
}

class _WaterfallChartWidgetState extends State<WaterfallChartWidget>
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
    final int net = widget.income - widget.expense;
    final double incomeDouble = widget.income.toDouble();
    final double expenseDouble = widget.expense.toDouble();

    final double minYVal = net < 0 ? net.toDouble() : 0.0;
    final double maxYVal = incomeDouble > expenseDouble
        ? incomeDouble
        : expenseDouble;

    // Calculate range to apply a nice padding
    final double range = maxYVal - minYVal;

    // If there are values, add 15% padding at the top and bottom to prevent the bars from touching the edges of the chart.
    // If range is 0 (i.e. both income and expense are 0), use a default scale.
    final double padding = range > 0 ? range * 0.15 : 100.0;

    final double finalMinY = minYVal - (minYVal < 0 ? padding : 0.0);
    final double finalMaxY = maxYVal + padding;

    // Waterfall: 3 bars
    // Bar 0: income (from 0 to income)
    // Bar 1: expense (from 0 to expense)
    // Bar 2: net (from 0 to net)

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final t = _animation.value;
        final double incomeH = incomeDouble * t;
        final double expenseH = expenseDouble * t;
        final double netH = net.toDouble() * t;

        return Column(
          children: [
            AspectRatio(
              aspectRatio: 1.7,
              child: BarChart(
                BarChartData(
                  minY: finalMinY,
                  maxY: finalMaxY,
                  barTouchData: const BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = ['Receita', 'Despesa', 'Saldo'];
                          final i = value.toInt();
                          if (i < 0 || i >= labels.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[i],
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
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: cs.outlineVariant.withValues(alpha: 0.2),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    // Income bar
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          fromY: 0,
                          toY: incomeH,
                          color: cs.primary,
                          width: 32,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    // Expense bar
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          fromY: 0,
                          toY: expenseH,
                          color: cs.error,
                          width: 32,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    // Net bar
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          fromY: 0,
                          toY: netH,
                          color: net >= 0 ? cs.tertiary : cs.error,
                          width: 32,
                          borderRadius: net >= 0
                              ? const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                )
                              : const BorderRadius.vertical(
                                  bottom: Radius.circular(8),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _WaterfallLegendItem(
                  color: cs.primary,
                  label: 'Receita',
                  value: widget.income,
                ),
                _WaterfallLegendItem(
                  color: cs.error,
                  label: 'Despesa',
                  value: widget.expense,
                ),
                _WaterfallLegendItem(
                  color: net >= 0 ? cs.tertiary : cs.error,
                  label: 'Saldo',
                  value: net,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WaterfallLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _WaterfallLegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.formatCents(value),
          style: tt.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}
