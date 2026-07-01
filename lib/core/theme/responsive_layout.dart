import 'package:flutter/material.dart';

import 'breakpoints.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    required this.expanded,
  });

  final Widget compact;
  final Widget? medium;
  final Widget expanded;

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isExpanded(context)) return expanded;
    if (Breakpoints.isMedium(context)) return medium ?? expanded;
    return compact;
  }
}

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, BoxConstraints constraints)
  builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: builder);
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.padding,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cols = Breakpoints.gridColumns(context);
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: [
          for (final child in children)
            SizedBox(width: _calcWidth(context, cols), child: child),
        ],
      ),
    );
  }

  double _calcWidth(BuildContext context, int cols) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = (padding as EdgeInsets?)?.horizontal ?? 0;
    final available = screenWidth - horizontalPadding - (cols - 1) * spacing;
    return available / cols;
  }
}
