import 'package:flutter/material.dart';

class Breakpoints {
  Breakpoints._();

  static const compact = 600.0;
  static const medium = 840.0;
  static const expanded = 1200.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isMedium(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= compact && w < medium;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;

  static int gridColumns(BuildContext context) {
    if (isExpanded(context)) return 12;
    if (isMedium(context)) return 8;
    return 4;
  }

  static double contentMaxWidth(BuildContext context) {
    if (isWide(context)) return 1400;
    if (isExpanded(context)) return 1100;
    if (isMedium(context)) return 800;
    return double.infinity;
  }
}
