import 'package:flutter/material.dart';

/// Typography tokens for an Operate-mode surface: one family (Roboto, the
/// Flutter engine default — declared explicitly rather than left implicit),
/// a tight ~1.11-1.17 scale ratio (denser than a marketing scale), and three
/// monetary styles outside the M3 roles for tabular-figure amount rendering.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Roboto';

  static TextTheme buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      displayLarge: _style(40, 48, FontWeight.w400, colorScheme.onSurface),
      displayMedium: _style(34, 42, FontWeight.w400, colorScheme.onSurface),
      displaySmall: _style(29, 36, FontWeight.w400, colorScheme.onSurface),
      headlineLarge: _style(26, 32, FontWeight.w600, colorScheme.onSurface),
      headlineMedium: _style(23, 29, FontWeight.w600, colorScheme.onSurface),
      headlineSmall: _style(20, 26, FontWeight.w600, colorScheme.onSurface),
      titleLarge: _style(18, 24, FontWeight.w600, colorScheme.onSurface),
      titleMedium: _style(16, 22, FontWeight.w600, colorScheme.onSurface),
      titleSmall: _style(14, 20, FontWeight.w600, colorScheme.onSurface),
      bodyLarge: _style(16, 24, FontWeight.w400, colorScheme.onSurface),
      bodyMedium: _style(14, 20, FontWeight.w400, colorScheme.onSurface),
      bodySmall: _style(12, 16, FontWeight.w400, colorScheme.onSurfaceVariant),
      labelLarge: _style(14, 20, FontWeight.w500, colorScheme.onSurface),
      labelMedium: _style(12, 16, FontWeight.w500, colorScheme.onSurfaceVariant),
      labelSmall: _style(11, 16, FontWeight.w500, colorScheme.onSurfaceVariant),
    );
  }

  static TextStyle _style(double size, double height, FontWeight weight, Color color) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      color: color,
    );
  }

  /// Dashboard hero total-balance figure.
  static const TextStyle amountLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Per-account balances, card-level totals.
  static const TextStyle amountMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 1.2,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Transaction-list trailing amount, chart tooltips.
  static const TextStyle amountSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
