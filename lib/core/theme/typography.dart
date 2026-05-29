import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme get textTheme {
    return GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        displaySmall: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.0,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
        titleSmall: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.1),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelMedium: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.8),
        labelSmall: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.8),
        bodyLarge: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0.15),
        bodyMedium: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0.25),
        bodySmall: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0.4),
      ),
    );
  }

  static TextStyle get monospace {
    return GoogleFonts.firaCode(
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
    );
  }
}
