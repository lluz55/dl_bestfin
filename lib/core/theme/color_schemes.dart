import 'package:flutter/material.dart';

const Color kSeedColor = Color(0xFF3D5AFE); // Indigo A400 — fallback

ColorScheme fallbackLight = ColorScheme.fromSeed(
  seedColor: kSeedColor,
  brightness: Brightness.light,
);

ColorScheme fallbackDark = ColorScheme.fromSeed(
  seedColor: kSeedColor,
  brightness: Brightness.dark,
);

@immutable
class CustomColors extends ThemeExtension<CustomColors> {
  const CustomColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.investment,
    required this.chartPrimary,
    required this.surfaceGlass,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color investment;
  final Color chartPrimary;
  final Color surfaceGlass;

  @override
  CustomColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? investment,
    Color? chartPrimary,
    Color? surfaceGlass,
  }) {
    return CustomColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      investment: investment ?? this.investment,
      chartPrimary: chartPrimary ?? this.chartPrimary,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) {
      return this;
    }
    return CustomColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      investment: Color.lerp(investment, other.investment, t)!,
      chartPrimary: Color.lerp(chartPrimary, other.chartPrimary, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
    );
  }

  static const light = CustomColors(
    income: Color(0xFF2E7D32),
    expense: Color(0xFFD32F2F),
    transfer: Color(0xFF1565C0),
    investment: Color(0xFFE65100),
    chartPrimary: Color(0xFF00BCD4),
    surfaceGlass: Color(0x1AFFFFFF),
  );

  static const dark = CustomColors(
    income: Color(0xFF66BB6A),
    expense: Color(0xFFEF5350),
    transfer: Color(0xFF42A5F5),
    investment: Color(0xFFFFB300),
    chartPrimary: Color(0xFF26C6DA),
    surfaceGlass: Color(0x1AFFFFFF),
  );

  /// Returns a version of [base] whose semantic colors are harmonized with
  /// [scheme] using Material Color Utilities blend logic.
  static CustomColors harmonized(CustomColors base, ColorScheme scheme) {
    Color h(Color c) => _harmonize(c, scheme.primary);
    return CustomColors(
      income: h(base.income),
      expense: h(base.expense),
      transfer: h(base.transfer),
      investment: h(base.investment),
      chartPrimary: h(base.chartPrimary),
      surfaceGlass: base.surfaceGlass,
    );
  }

  /// Blends [design] toward [key] by 8% (Material spec: semantic harmonization).
  static Color _harmonize(Color design, Color key) {
    return Color.alphaBlend(key.withAlpha(20), design);
  }
}
