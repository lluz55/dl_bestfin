import 'package:flutter/material.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';

class SpendingHeatmapWidget extends StatefulWidget {
  final List<HeatmapCell> cells;

  const SpendingHeatmapWidget({super.key, required this.cells});

  @override
  State<SpendingHeatmapWidget> createState() => _SpendingHeatmapWidgetState();
}

class _SpendingHeatmapWidgetState extends State<SpendingHeatmapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  static const _weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
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

    // Build a 7×24 grid (weekday × hour)
    final Map<String, int> grid = {};
    int maxVal = 1;
    for (final cell in widget.cells) {
      final key = '${cell.weekday}-${cell.hour}';
      grid[key] = (grid[key] ?? 0) + cell.totalAmount;
      if (grid[key]! > maxVal) maxVal = grid[key]!;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hour labels (sample every 4h)
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Row(
                children: List.generate(7, (h) {
                  final hour = h * 4;
                  return Expanded(
                    child: Text(
                      '${hour}h',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 4),
            ...List.generate(7, (dayIdx) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        _weekdays[dayIdx],
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(fontSize: 10),
                      ),
                    ),
                    ...List.generate(24, (hour) {
                      final key = '${dayIdx + 1}-$hour';
                      final val = grid[key] ?? 0;
                      final intensity = maxVal > 0
                          ? (val / maxVal) * _animation.value
                          : 0.0;
                      return Expanded(
                        child: Container(
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              cs.surfaceContainerHigh,
                              cs.primary,
                              intensity,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Menos',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                ...List.generate(5, (i) {
                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        cs.surfaceContainerHigh,
                        cs.primary,
                        i / 4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                Text(
                  'Mais',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
