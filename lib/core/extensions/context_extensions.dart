import 'package:flutter/material.dart';

import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/theme/color_schemes.dart';
import 'package:bestfin/core/theme/motion.dart';
import 'package:bestfin/core/theme/shapes.dart';

extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;

  bool get isDark => theme.brightness == Brightness.dark;

  CustomColors get customColors =>
      theme.extension<CustomColors>() ?? CustomColors.light;

  ExpressiveShapes get shapes =>
      theme.extension<ExpressiveShapes>() ?? ExpressiveShapes.defaultShapes;

  ExpressiveMotion get motion =>
      theme.extension<ExpressiveMotion>() ?? ExpressiveMotion.defaultMotion;

  /// Cor de superfície com transparência para efeito glassmorphism.
  Color get glassSurface => customColors.surfaceGlass;

  /// Gradiente principal do app (primary → secondary diagonal).
  LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [colorScheme.primary, colorScheme.secondary],
  );

  bool get isCompact => Breakpoints.isCompact(this);
  bool get isMedium => Breakpoints.isMedium(this);
  bool get isExpanded => Breakpoints.isExpanded(this);
  bool get isWide => Breakpoints.isWide(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
}
