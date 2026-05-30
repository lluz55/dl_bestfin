import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/features/dashboard/domain/models/dashboard_data.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

class SpendingDonut extends StatefulWidget {
  final List<DashboardCategorySpending> categoryExpenses;

  const SpendingDonut({super.key, required this.categoryExpenses});

  @override
  State<SpendingDonut> createState() => _SpendingDonutState();
}

class _SpendingDonutState extends State<SpendingDonut> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final hasData =
        widget.categoryExpenses.isNotEmpty &&
        widget.categoryExpenses.any((e) => e.amountInCents > 0);

    return AnimatedCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DISTRIBUIÇÃO DE GASTOS',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 32),
          if (!hasData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 64,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sem despesas registradas este mês.',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    _touchedIndex = -1;
                                    return;
                                  }
                                  _touchedIndex = pieTouchResponse
                                      .touchedSection!
                                      .touchedSectionIndex;
                                });
                              },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 4,
                        centerSpaceRadius: 40,
                        sections: _buildSections(cs),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.categoryExpenses.take(5).length,
                      (index) => _buildLegendItem(
                        widget.categoryExpenses[index],
                        index == _touchedIndex,
                        cs,
                        tt,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(ColorScheme cs) {
    return List.generate(widget.categoryExpenses.length, (i) {
      final item = widget.categoryExpenses[i];
      final isTouched = i == _touchedIndex;
      final double radius = isTouched ? 28 : 20;

      Color color;
      if (item.category != null) {
        color = item.category!.parsedColor;
      } else {
        color = cs.outline;
      }

      return PieChartSectionData(
        color: color,
        value: item.amountInCents.toDouble(),
        title: '',
        radius: radius,
        badgeWidget: isTouched
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(item.percentage * 100).toStringAsFixed(0)}%',
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              )
            : null,
        badgePositionPercentageOffset: 1.4,
      );
    });
  }

  Widget _buildLegendItem(
    DashboardCategorySpending item,
    bool isSelected,
    ColorScheme cs,
    TextTheme tt,
  ) {
    Color color = item.category?.parsedColor ?? cs.outline;
    final double valAmount = item.amountInCents / 100.0;
    final formattedAmount = CurrencyFormatter.valuesHidden
        ? 'R\$ •••••'
        : 'R\$ ${valAmount.toStringAsFixed(0)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.surfaceContainerHighest.withValues(alpha: 0.7)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelLarge?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: cs.onSurface,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${(item.percentage * 100).toStringAsFixed(0)}%',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              formattedAmount,
              style: tt.labelMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    fontSize: 11,
                  )
                  .merge(AppTypography.monospace),
            ),
          ],
        ),
      ),
    );
  }
}
