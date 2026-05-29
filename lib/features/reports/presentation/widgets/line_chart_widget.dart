import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';

class NetWorthLineChartWidget extends StatefulWidget {
  final List<NetWorthPoint> points;

  const NetWorthLineChartWidget({super.key, required this.points});

  @override
  State<NetWorthLineChartWidget> createState() =>
      _NetWorthLineChartWidgetState();
}

class _NetWorthLineChartWidgetState extends State<NetWorthLineChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(NetWorthLineChartWidget old) {
    super.didUpdateWidget(old);
    if (old.points != widget.points) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.points.isEmpty) {
      return const Center(child: Text('Nenhum dado disponível'));
    }

    final values = widget.points.map((p) => p.netWorth.toDouble()).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxVal - minVal) * 0.1).abs().clamp(
      1000.0,
      double.infinity,
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        // Clip points to animate line drawing
        final visibleCount = ((widget.points.length) * _animation.value)
            .ceil()
            .clamp(1, widget.points.length);

        final spots = List.generate(visibleCount, (i) {
          return FlSpot(i.toDouble(), widget.points[i].netWorth.toDouble());
        });

        return AspectRatio(
          aspectRatio: 2.0,
          child: LineChart(
            LineChartData(
              minY: minVal - padding,
              maxY: maxVal + padding,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final i = s.x.toInt();
                    if (i >= widget.points.length) return null;
                    final p = widget.points[i];
                    final months = [
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
                    return LineTooltipItem(
                      '${months[p.date.month - 1]} ${p.date.year}\nR\$ ${(p.netWorth / 100).toStringAsFixed(2)}',
                      Theme.of(
                        context,
                      ).textTheme.labelSmall!.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }).toList(),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= widget.points.length)
                        return const SizedBox();
                      final p = widget.points[i];
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
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          months[p.date.month - 1],
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
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
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: cs.primary,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                      radius: 4,
                      color: cs.primary,
                      strokeWidth: 2,
                      strokeColor: cs.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cs.primary.withValues(alpha: 0.2),
                        cs.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CashFlowLineChartWidget extends StatefulWidget {
  final List<CashFlowPoint> points;

  const CashFlowLineChartWidget({super.key, required this.points});

  @override
  State<CashFlowLineChartWidget> createState() =>
      _CashFlowLineChartWidgetState();
}

class _CashFlowLineChartWidgetState extends State<CashFlowLineChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
    if (widget.points.isEmpty) {
      return const Center(child: Text('Nenhum dado disponível'));
    }

    final values = widget.points
        .map((p) => p.cumulativeBalance.toDouble())
        .toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxVal - minVal) * 0.1).abs().clamp(
      1000.0,
      double.infinity,
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final visibleCount = ((widget.points.length) * _animation.value)
            .ceil()
            .clamp(1, widget.points.length);

        final spots = List.generate(visibleCount, (i) {
          return FlSpot(
            i.toDouble(),
            widget.points[i].cumulativeBalance.toDouble(),
          );
        });

        return AspectRatio(
          aspectRatio: 2.0,
          child: LineChart(
            LineChartData(
              minY: minVal - padding,
              maxY: maxVal + padding,
              titlesData: const FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
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
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: cs.tertiary,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cs.tertiary.withValues(alpha: 0.2),
                        cs.tertiary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
