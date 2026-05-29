import 'package:flutter/material.dart';

import '../theme/color_schemes.dart';
import '../theme/motion.dart';
import '../theme/shapes.dart';

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
}
