import 'package:flutter/material.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final String icon;
  final String color;
  final double size;

  static Color hexToColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = hexToColor(color);
    final iconData = IconMapper.fromString(icon);

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
