import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:bestfin/features/reports/domain/models/sankey_models.dart';
import 'package:bestfin/core/utils/currency_formatter.dart';

// ─── Internal layout data ────────────────────────────────────────────────────

class _NodeLayout {
  final SankeyNode node;
  final Rect rect;
  const _NodeLayout(this.node, this.rect);
}

class _LinkLayout {
  final SankeyLink link;
  final double sx, syTop, syBottom;
  final double tx, tyTop, tyBottom;
  final Color sourceColor, targetColor;

  const _LinkLayout({
    required this.link,
    required this.sx,
    required this.syTop,
    required this.syBottom,
    required this.tx,
    required this.tyTop,
    required this.tyBottom,
    required this.sourceColor,
    required this.targetColor,
  });
}

class _SankeyLayout {
  final List<_NodeLayout> nodes;
  final List<_LinkLayout> links;
  final double col0X, col1X, col2X;
  final double nodeWidth;

  const _SankeyLayout({
    required this.nodes,
    required this.links,
    required this.col0X,
    required this.col1X,
    required this.col2X,
    required this.nodeWidth,
  });
}

// ─── Layout builder ──────────────────────────────────────────────────────────

_SankeyLayout _buildLayout(SankeyData data, Size size) {
  const nodeWidth = 18.0;
  const hPad = 84.0; // space for side labels
  const vPad = 28.0; // space for column headers
  const nodeGap = 8.0;
  const bottomPad = 12.0;

  const col0X = hPad;
  final col2X = size.width - hPad - nodeWidth;
  final col1X = (col0X + col2X) / 2;

  final colXs = [col0X, col1X, col2X];
  final nodeMap = <String, _NodeLayout>{};

  for (int c = 0; c < 3; c++) {
    final colNodes = data.nodes.where((n) => n.column == c).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (colNodes.isEmpty) continue;

    final totalVal = colNodes.fold<int>(0, (s, n) => s + n.value);
    final gaps = (colNodes.length - 1) * nodeGap;
    final availH = size.height - vPad - gaps - bottomPad;

    double y = vPad;
    for (final node in colNodes) {
      final h = math.max(6.0, availH * node.value / totalVal);
      nodeMap[node.id] = _NodeLayout(
        node,
        Rect.fromLTWH(colXs[c], y, nodeWidth, h),
      );
      y += h + nodeGap;
    }
  }

  // Pre-compute totals for proportional link heights
  final srcTotals = <String, int>{};
  final tgtTotals = <String, int>{};
  for (final link in data.links) {
    srcTotals[link.sourceId] = (srcTotals[link.sourceId] ?? 0) + link.value;
    tgtTotals[link.targetId] = (tgtTotals[link.targetId] ?? 0) + link.value;
  }

  final srcOffsets = <String, double>{};
  final tgtOffsets = <String, double>{};
  final linkLayouts = <_LinkLayout>[];

  for (final link in data.links) {
    final src = nodeMap[link.sourceId];
    final tgt = nodeMap[link.targetId];
    if (src == null || tgt == null) continue;

    final srcTotal = srcTotals[link.sourceId]!;
    final tgtTotal = tgtTotals[link.targetId]!;

    final srcOff = srcOffsets[link.sourceId] ?? 0.0;
    final tgtOff = tgtOffsets[link.targetId] ?? 0.0;

    final lhSrc = src.rect.height * link.value / srcTotal;
    final lhTgt = tgt.rect.height * link.value / tgtTotal;

    linkLayouts.add(
      _LinkLayout(
        link: link,
        sx: src.rect.right,
        syTop: src.rect.top + srcOff,
        syBottom: src.rect.top + srcOff + lhSrc,
        tx: tgt.rect.left,
        tyTop: tgt.rect.top + tgtOff,
        tyBottom: tgt.rect.top + tgtOff + lhTgt,
        sourceColor: src.node.color,
        targetColor: tgt.node.color,
      ),
    );

    srcOffsets[link.sourceId] = srcOff + lhSrc;
    tgtOffsets[link.targetId] = tgtOff + lhTgt;
  }

  return _SankeyLayout(
    nodes: nodeMap.values.toList(),
    links: linkLayouts,
    col0X: col0X,
    col1X: col1X,
    col2X: col2X,
    nodeWidth: nodeWidth,
  );
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _SankeyPainter extends CustomPainter {
  final _SankeyLayout layout;
  final double progress;
  final String? highlightedNodeId;
  final _LinkLayout? highlightedLink;
  final List<String> columnLabels;
  final Color textColor;
  final Color headerColor;

  const _SankeyPainter({
    required this.layout,
    required this.progress,
    required this.columnLabels,
    required this.textColor,
    required this.headerColor,
    this.highlightedNodeId,
    this.highlightedLink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final anyHighlight = highlightedNodeId != null || highlightedLink != null;

    // Draw links (below nodes)
    for (final link in layout.links) {
      final isHl =
          highlightedLink == link ||
          (highlightedNodeId != null &&
              (link.link.sourceId == highlightedNodeId ||
                  link.link.targetId == highlightedNodeId));
      _drawLink(canvas, link, anyHighlight && !isHl, isHl);
    }

    // Draw nodes
    for (final node in layout.nodes) {
      final isHl = node.node.id == highlightedNodeId;
      final isDim = anyHighlight && !isHl && highlightedLink == null;
      _drawNode(canvas, node, isHl, isDim);
    }

    // Draw column headers
    if (columnLabels.length >= 3) {
      _drawHeader(canvas, columnLabels[0], layout.col0X, layout.nodeWidth);
      _drawHeader(canvas, columnLabels[1], layout.col1X, layout.nodeWidth);
      _drawHeader(canvas, columnLabels[2], layout.col2X, layout.nodeWidth);
    }
  }

  void _drawLink(
    Canvas canvas,
    _LinkLayout link,
    bool dimmed,
    bool highlighted,
  ) {
    final midX = (link.sx + link.tx) / 2;

    final path = Path()
      ..moveTo(link.sx, link.syTop)
      ..cubicTo(midX, link.syTop, midX, link.tyTop, link.tx, link.tyTop)
      ..lineTo(link.tx, link.tyBottom)
      ..cubicTo(
        midX,
        link.tyBottom,
        midX,
        link.syBottom,
        link.sx,
        link.syBottom,
      )
      ..close();

    final baseAlpha = highlighted ? 0.70 : (dimmed ? 0.06 : 0.38);
    final alpha = baseAlpha * progress;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader =
          LinearGradient(
            colors: [
              link.sourceColor.withValues(alpha: alpha),
              link.targetColor.withValues(alpha: alpha),
            ],
          ).createShader(
            Rect.fromLTRB(link.sx, link.syTop, link.tx, link.tyBottom),
          );

    canvas.drawPath(path, paint);
  }

  void _drawNode(
    Canvas canvas,
    _NodeLayout node,
    bool highlighted,
    bool dimmed,
  ) {
    final alpha = (highlighted ? 1.0 : (dimmed ? 0.3 : 0.88)) * progress;
    final paint = Paint()
      ..color = node.node.color.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(node.rect, const Radius.circular(3)),
      paint,
    );

    // Label
    final isLeft = node.node.column == 0;
    final isRight = node.node.column == 2;
    final isMiddle = node.node.column == 1;

    final labelAlpha = (highlighted ? 1.0 : (dimmed ? 0.25 : 0.85)) * progress;
    final labelStyle = TextStyle(
      color: textColor.withValues(alpha: labelAlpha),
      fontSize: 10,
      fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
      height: 1.2,
    );

    String truncated = node.node.label;
    if (truncated.length > 14) {
      truncated = '${truncated.substring(0, 13)}…';
    }

    final tp = TextPainter(
      text: TextSpan(text: truncated, style: labelStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 78);

    final nodeCenter = node.rect.top + node.rect.height / 2;
    final ty = nodeCenter - tp.height / 2;

    if (isLeft) {
      tp.paint(canvas, Offset(node.rect.left - tp.width - 5, ty));
    } else if (isRight || isMiddle) {
      tp.paint(canvas, Offset(node.rect.right + 5, ty));
    }
  }

  void _drawHeader(Canvas canvas, String label, double colX, double nodeWidth) {
    final alpha = 0.55 * progress;
    final tp = TextPainter(
      text: TextSpan(
        text: label.toUpperCase(),
        style: TextStyle(
          color: headerColor.withValues(alpha: alpha),
          fontSize: 8,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 100);

    tp.paint(canvas, Offset(colX + nodeWidth / 2 - tp.width / 2, 8));
  }

  @override
  bool shouldRepaint(_SankeyPainter old) =>
      old.progress != progress ||
      old.highlightedNodeId != highlightedNodeId ||
      old.highlightedLink != highlightedLink ||
      old.layout != layout;
}

// ─── Public Widget ───────────────────────────────────────────────────────────

class SankeyWidget extends StatefulWidget {
  final SankeyData data;

  const SankeyWidget({super.key, required this.data});

  @override
  State<SankeyWidget> createState() => _SankeyWidgetState();
}

class _SankeyWidgetState extends State<SankeyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  late final TransformationController _transform;

  String? _highlightedNodeId;
  _LinkLayout? _highlightedLink;

  _SankeyLayout? _layout;
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _transform = TransformationController();
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(SankeyWidget old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) {
      _layout = null;
      _highlightedNodeId = null;
      _highlightedLink = null;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _transform.dispose();
    super.dispose();
  }

  _SankeyLayout _getLayout(Size size) {
    if (_layout != null && _lastSize == size) return _layout!;
    _layout = _buildLayout(widget.data, size);
    _lastSize = size;
    return _layout!;
  }

  void _handleTap(TapUpDetails details) {
    final layout = _layout;
    if (layout == null) return;

    // Convert from widget coords to scene coords (accounting for zoom/pan)
    final scenePos = _transform.toScene(details.localPosition);

    // Node hit test
    for (final n in layout.nodes) {
      if (n.rect.inflate(6).contains(scenePos)) {
        setState(() {
          _highlightedNodeId = _highlightedNodeId == n.node.id
              ? null
              : n.node.id;
          _highlightedLink = null;
        });
        return;
      }
    }

    // Link hit test (rough bounding box)
    for (final link in layout.links) {
      final bounds = Rect.fromLTRB(
        link.sx,
        math.min(link.syTop, link.tyTop) - 6,
        link.tx,
        math.max(link.syBottom, link.tyBottom) + 6,
      );
      if (bounds.contains(scenePos)) {
        setState(() {
          _highlightedLink = link;
          _highlightedNodeId = null;
        });
        return;
      }
    }

    setState(() {
      _highlightedNodeId = null;
      _highlightedLink = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Nenhum dado para o período selecionado'),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final textColor = cs.onSurface;
    final headerColor = cs.onSurfaceVariant;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final layout = _getLayout(size);

              return InteractiveViewer(
                transformationController: _transform,
                minScale: 0.5,
                maxScale: 4.0,
                child: GestureDetector(
                  onTapUp: _handleTap,
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context2, child2) => CustomPaint(
                      size: size,
                      painter: _SankeyPainter(
                        layout: layout,
                        progress: _anim.value,
                        highlightedNodeId: _highlightedNodeId,
                        highlightedLink: _highlightedLink,
                        columnLabels: widget.data.columnLabels,
                        textColor: textColor,
                        headerColor: headerColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_highlightedLink != null)
          _LinkDetail(link: _highlightedLink!, layout: _layout),
        if (_highlightedNodeId != null)
          _NodeDetail(nodeId: _highlightedNodeId!, layout: _layout),
      ],
    );
  }
}

// ─── Detail chips shown on tap ───────────────────────────────────────────────

class _LinkDetail extends StatelessWidget {
  final _LinkLayout link;
  final _SankeyLayout? layout;

  const _LinkDetail({required this.link, required this.layout});

  @override
  Widget build(BuildContext context) {
    final src = layout?.nodes
        .where((n) => n.node.id == link.link.sourceId)
        .firstOrNull;
    final tgt = layout?.nodes
        .where((n) => n.node.id == link.link.targetId)
        .firstOrNull;
    final amount = CurrencyFormatter.formatCents(link.link.value);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Text(
        '${src?.node.label ?? '?'} → ${tgt?.node.label ?? '?'}: $amount',
        style: Theme.of(context).textTheme.labelMedium,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _NodeDetail extends StatelessWidget {
  final String nodeId;
  final _SankeyLayout? layout;

  const _NodeDetail({required this.nodeId, required this.layout});

  @override
  Widget build(BuildContext context) {
    final node = layout?.nodes.where((n) => n.node.id == nodeId).firstOrNull;
    if (node == null) return const SizedBox.shrink();

    final amount = CurrencyFormatter.formatCents(node.node.value);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: node.node.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${node.node.label}: $amount',
            style: Theme.of(context).textTheme.labelMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
