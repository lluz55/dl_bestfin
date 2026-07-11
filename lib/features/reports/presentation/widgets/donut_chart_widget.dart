import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:bestfin/core/theme/typography.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/core/widgets/category_icon.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

class DonutChartWidget extends StatefulWidget {
  final List<CategorySpending> items;
  final int totalInCents;

  const DonutChartWidget({
    super.key,
    required this.items,
    required this.totalInCents,
  });

  @override
  State<DonutChartWidget> createState() => _DonutChartWidgetState();
}

class _DonutChartWidgetState extends State<DonutChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _touchedIndex;

  static const _colors = [
    Color(0xFF6750A4),
    Color(0xFF00BCD4),
    Color(0xFFFF7043),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFF9E9E9E),
  ];

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
  void didUpdateWidget(DonutChartWidget old) {
    super.didUpdateWidget(old);
    if (old.items != widget.items) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorFor(int index) {
    final item = widget.items[index];
    if (item.category != null) {
      try {
        return item.category!.parsedColor;
      } catch (_) {}
    }
    return _colors[index % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Column(
          children: [
            SizedBox(
              width: 240,
              child: AspectRatio(
                aspectRatio: 1.0,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) {
                    return PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  response?.touchedSection == null) {
                                _touchedIndex = null;
                                return;
                              }
                              _touchedIndex =
                                  response!.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        startDegreeOffset: -90,
                        sectionsSpace: 4,
                        centerSpaceRadius: 50,
                        sections: List.generate(widget.items.length, (i) {
                          final item = widget.items[i];
                          final isTouched = i == _touchedIndex;
                          return PieChartSectionData(
                            value: item.amountInCents.toDouble() * _animation.value,
                            color: _colorFor(i),
                            radius: isTouched ? 34 : 24,
                            showTitle: false,
                            badgeWidget: isTouched
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${(item.percentage * 100).toStringAsFixed(0)}%',
                                      style: tt.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  )
                                : null,
                            badgePositionPercentageOffset: 1.4,
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Legend
            ...List.generate(widget.items.length, (i) {
              final item = widget.items[i];
              final isSelected = i == _touchedIndex;
              final pct = (item.percentage * 100).toStringAsFixed(1);
              final amt = CurrencyFormatter.formatCents(item.amountInCents);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        decoration: BoxDecoration(
                          color: _colorFor(i),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (item.category != null) ...[
                        CategoryIcon(
                          icon: item.category!.icon,
                          color: item.category!.color,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.category?.displayName ?? 'Sem categoria',
                              style: tt.titleSmall?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: cs.onSurface,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$pct%',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        amt,
                        style: tt.labelLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            )
                            .merge(AppTypography.monospace),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
