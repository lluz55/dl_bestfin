import 'package:flutter/material.dart';

import 'package:bestfin/core/theme/color_schemes.dart';
import 'package:bestfin/core/theme/dimens.dart';
import 'package:bestfin/core/theme/motion.dart';
import 'package:bestfin/core/theme/shapes.dart';
import 'package:bestfin/core/theme/typography.dart';

class AppTheme {
  static ThemeData build(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final baseCustom = isLight ? CustomColors.light : CustomColors.dark;
    final custom = CustomColors.harmonized(baseCustom, scheme);

    final tt = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: tt,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: tt.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
      ),
      extensions: [
        custom,
        ExpressiveShapes.defaultShapes,
        ExpressiveMotion.defaultMotion,
      ],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: ExpressiveShapes.defaultShapes.button,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ExpressiveShapes.defaultShapes.button,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ExpressiveShapes.defaultShapes.button,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: ExpressiveShapes.defaultShapes.button,
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: ExpressiveShapes.defaultShapes.button,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: ExpressiveShapes.defaultShapes.card,
        ),
        elevation: 0,
        color: scheme.surfaceContainer,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: AppDimens.buttonMinSize,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: ExpressiveShapes.defaultShapes.button,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: AppDimens.buttonMinSize,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: ExpressiveShapes.defaultShapes.button,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: AppDimens.buttonMinSize,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: ExpressiveShapes.defaultShapes.button,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: AppDimens.buttonMinSizeCompact,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: ExpressiveShapes.defaultShapes.button,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: ExpressiveShapes.defaultShapes.button,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppDimens.minTapTarget,
            AppDimens.minTapTarget,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: ExpressiveShapes.defaultShapes.fabDefault,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: ExpressiveShapes.defaultShapes.dialog,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: ExpressiveShapes.defaultShapes.bottomSheet,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: ExpressiveShapes.defaultShapes.chip,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedRectangleBorder(
          borderRadius: ExpressiveShapes.defaultShapes.chip,
        ),
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        actionTextColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: ExpressiveShapes.defaultShapes.chip,
        ),
      ),
    );
  }

  static ThemeData get light => build(fallbackLight);
  static ThemeData get dark => build(fallbackDark);
}
