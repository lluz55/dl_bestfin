import 'package:flutter/material.dart';

class BadgeInfo {
  final String label;
  final Color color;
  const BadgeInfo(this.label, this.color);
}

class NameWithOptionalBadges extends StatelessWidget {
  const NameWithOptionalBadges({
    super.key,
    required this.name,
    this.nameStyle,
    this.badges = const [],
    this.badgePadding =
        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.badgeFontSize = 10,
    this.gapWidth = 6,
  });

  final String name;
  final TextStyle? nameStyle;
  final List<BadgeInfo> badges;
  final EdgeInsets badgePadding;
  final double badgeFontSize;
  final double gapWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final style = nameStyle ?? DefaultTextStyle.of(context).style;

        final namePainter = TextPainter(
          text: TextSpan(text: name, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final nameWidth = namePainter.width;

        final badgeHPadding =
            badgePadding.left + badgePadding.right;
        double totalBadgesWidth = 0;

        final badgeWidgets = <Widget>[];
        for (final badge in badges) {
          totalBadgesWidth += gapWidth;

          final badgePainter = TextPainter(
            text: TextSpan(
              text: badge.label,
              style: TextStyle(
                fontSize: badgeFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          totalBadgesWidth += badgePainter.width + badgeHPadding;

          badgeWidgets.add(_buildBadge(badge));
        }

        if (nameWidth + totalBadgesWidth <= availableWidth) {
          return Row(
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
              ...badgeWidgets.expand(
                (b) => [SizedBox(width: gapWidth), b],
              ),
            ],
          );
        } else {
          return Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildBadge(BadgeInfo info) {
    return Container(
      padding: badgePadding,
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        info.label,
        style: TextStyle(
          fontSize: badgeFontSize,
          fontWeight: FontWeight.w600,
          color: info.color,
        ),
      ),
    );
  }
}
