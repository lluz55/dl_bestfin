import 'package:flutter/material.dart';

class DashboardGrid extends StatelessWidget {
  const DashboardGrid({
    super.key,
    required this.children,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.padding,
    this.minWidgetWidth = 350,
    this.maxWidgetWidth = 450,
  });

  final List<Widget> children;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final double minWidgetWidth;
  final double maxWidgetWidth;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = _computeColumns(screenWidth);

    if (columns <= 1) {
      return _SingleColumn(
        padding: padding,
        mainAxisSpacing: mainAxisSpacing,
        minWidgetWidth: minWidgetWidth,
        maxWidgetWidth: maxWidgetWidth,
        children: children,
      );
    }
    if (columns == 2) {
      return _TwoColumn(
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        padding: padding,
        minWidgetWidth: minWidgetWidth,
        maxWidgetWidth: maxWidgetWidth,
        children: children,
      );
    }
    return _ThreeColumn(
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      padding: padding,
      minWidgetWidth: minWidgetWidth,
      maxWidgetWidth: maxWidgetWidth,
      children: children,
    );
  }

  // FIX 2: era -48, mas _buildMediumLayout remove apenas 16px × 2 = 32px de padding
  int _computeColumns(double screenWidth) {
    final availableWidth = screenWidth - 32;
    if (availableWidth >= minWidgetWidth * 3 + crossAxisSpacing * 2) return 3;
    if (availableWidth >= minWidgetWidth * 2 + crossAxisSpacing) return 2;
    return 1;
  }
}

// FIX 1: _SingleColumn agora recebe min/maxWidgetWidth e aplica ConstrainedBox em cada filho,
// centralizando o conteúdo quando a tela for mais larga que maxWidgetWidth.
class _SingleColumn extends StatelessWidget {
  const _SingleColumn({
    required this.children,
    this.padding,
    this.mainAxisSpacing = 12,
    this.minWidgetWidth = 350,
    this.maxWidgetWidth = 450,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double mainAxisSpacing;
  final double minWidgetWidth;
  final double maxWidgetWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: mainAxisSpacing),
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidgetWidth,
                maxWidth: maxWidgetWidth,
              ),
              child: children[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({
    required this.children,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.padding,
    this.minWidgetWidth = 350,
    this.maxWidgetWidth = 450,
  });

  final List<Widget> children;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final double minWidgetWidth;
  final double maxWidgetWidth;

  @override
  Widget build(BuildContext context) {
    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(children[i]);
      } else {
        rightColumn.add(children[i]);
      }
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidgetWidth,
                maxWidth: maxWidgetWidth,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < leftColumn.length; i++) ...[
                    if (i > 0) SizedBox(height: mainAxisSpacing),
                    leftColumn[i],
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: crossAxisSpacing),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidgetWidth,
                maxWidth: maxWidgetWidth,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < rightColumn.length; i++) ...[
                    if (i > 0) SizedBox(height: mainAxisSpacing),
                    rightColumn[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeColumn extends StatelessWidget {
  const _ThreeColumn({
    required this.children,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.padding,
    this.minWidgetWidth = 350,
    this.maxWidgetWidth = 450,
  });

  final List<Widget> children;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final double minWidgetWidth;
  final double maxWidgetWidth;

  @override
  Widget build(BuildContext context) {
    final sidebarLeft = <Widget>[];
    final mainContent = <Widget>[];
    final sidebarRight = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      if (i < 2) {
        sidebarLeft.add(children[i]);
      } else if (i < 5) {
        mainContent.add(children[i]);
      } else {
        sidebarRight.add(children[i]);
      }
    }

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidgetWidth,
                maxWidth: maxWidgetWidth,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < sidebarLeft.length; i++) ...[
                    if (i > 0) SizedBox(height: mainAxisSpacing),
                    sidebarLeft[i],
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: crossAxisSpacing),
          // FIX 3: era Expanded (sem limite), agora Flexible + ConstrainedBox como as sidebars
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidgetWidth,
                maxWidth: maxWidgetWidth,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < mainContent.length; i++) ...[
                    if (i > 0) SizedBox(height: mainAxisSpacing),
                    mainContent[i],
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: crossAxisSpacing),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidgetWidth,
                maxWidth: maxWidgetWidth,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < sidebarRight.length; i++) ...[
                    if (i > 0) SizedBox(height: mainAxisSpacing),
                    sidebarRight[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
