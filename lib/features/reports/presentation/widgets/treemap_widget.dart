import 'package:flutter/material.dart';
import 'package:bestfin/features/reports/domain/models/report_models.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

class TreemapWidget extends StatefulWidget {
  final List<TreemapNode> nodes;
  final void Function(TreemapNode node)? onTap;

  const TreemapWidget({super.key, required this.nodes, this.onTap});

  @override
  State<TreemapWidget> createState() => _TreemapWidgetState();
}

class _TreemapWidgetState extends State<TreemapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void didUpdateWidget(TreemapWidget old) {
    super.didUpdateWidget(old);
    if (old.nodes != widget.nodes) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final rects = _squarify(
              widget.nodes,
              Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight),
            );

            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                children: List.generate(rects.length, (i) {
                  final node = widget.nodes[i];
                  final rect = rects[i];
                  Color nodeColor;
                  try {
                    final hex = node.color.replaceFirst('#', '');
                    nodeColor = Color(int.parse('FF$hex', radix: 16));
                  } catch (_) {
                    nodeColor = Theme.of(context).colorScheme.primary;
                  }

                  return Positioned(
                    left: rect.left + 1,
                    top: rect.top + 1,
                    width: (rect.width - 2).clamp(0, double.infinity),
                    height: (rect.height - 2).clamp(0, double.infinity),
                    child: GestureDetector(
                      onTap: () => widget.onTap?.call(node),
                      child: AnimatedOpacity(
                        opacity: _animation.value,
                        duration: Duration.zero,
                        child: Container(
                          decoration: BoxDecoration(
                            color: nodeColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: rect.width > 60 && rect.height > 30
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        node.label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 10,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                    if (rect.height > 48)
                                      Text(
                                        CurrencyFormatter.valuesHidden
                                            ? 'R\$ •••••'
                                            : 'R\$ ${(node.value / 100).toStringAsFixed(0)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.white70,
                                              fontSize: 9,
                                            ),
                                      ),
                                  ],
                                )
                              : const SizedBox(),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }

  // Simple slice-and-dice treemap algorithm
  List<Rect> _squarify(List<TreemapNode> nodes, Rect bounds) {
    if (nodes.isEmpty) return [];
    final totalValue = nodes.fold<int>(0, (sum, n) => sum + n.value);
    if (totalValue == 0) return List.filled(nodes.length, Rect.zero);

    final List<Rect> result = [];
    _divide(nodes, bounds, totalValue, result);
    return result;
  }

  void _divide(
    List<TreemapNode> nodes,
    Rect bounds,
    int total,
    List<Rect> result,
  ) {
    if (nodes.isEmpty) return;

    final isHorizontal = bounds.width >= bounds.height;
    double offset = 0;

    for (int i = 0; i < nodes.length; i++) {
      final ratio = nodes[i].value / total;
      if (isHorizontal) {
        final w = bounds.width * ratio;
        result.add(
          Rect.fromLTWH(bounds.left + offset, bounds.top, w, bounds.height),
        );
        offset += w;
      } else {
        final h = bounds.height * ratio;
        result.add(
          Rect.fromLTWH(bounds.left, bounds.top + offset, bounds.width, h),
        );
        offset += h;
      }
    }
  }
}
