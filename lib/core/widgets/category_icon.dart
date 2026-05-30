import 'package:flutter/material.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.parentIcon,
    this.parentColor,
  });

  final String icon;
  final String color;
  final double size;
  final String? parentIcon;
  final String? parentColor;

  static Color hexToColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = hexToColor(color);
    final iconData = IconMapper.fromString(icon);

    if (parentIcon != null && parentColor != null) {
      final pBgColor = hexToColor(parentColor!);
      final pIconData = IconMapper.fromString(parentIcon!);

      // Parent shifted to background, Child fully in foreground
      final double subSize = size * 0.7; // Child occupies 70% of area
      final double pSubSize = size * 0.7; // Parent occupies 70% of area

      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            // Parent icon (background, top-left)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: pSubSize,
                height: pSubSize,
                decoration: BoxDecoration(
                  color: pBgColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(pSubSize * 0.3),
                ),
                child: Icon(
                  pIconData,
                  size: pSubSize * 0.55,
                  color: pBgColor.withValues(
                    alpha: 0.5,
                  ), // slightly dimmed/transparent
                ),
              ),
            ),
            // Child icon (foreground, bottom-right)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: subSize,
                height: subSize,
                decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(subSize * 0.3),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Icon(iconData, size: subSize * 0.55, color: bgColor),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(iconData, size: size * 0.55, color: bgColor),
    );
  }
}
