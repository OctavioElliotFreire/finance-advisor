import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shape.dart';
import 'app_typography.dart';

/// Assembles the light/dark [ThemeData] from [AppPalette]'s flat tokens, the
/// shared [AppTypography]/[AppRadius] tokens, and every component theme this
/// app's screens actually use. Flat, hairline-border language over drop
/// shadows/tonal elevation, per `design.md`'s mockup-driven redesign — no
/// [ColorScheme.fromSeed] here, every role is spelled out explicitly so the
/// exact mockup hex values land, not a derived approximation.
///
/// The dark palette below is the real dark token table from
/// `handoff-app-financas-familiar.md` §2 (corrects an earlier placeholder
/// inversion written before that doc arrived) — dark-mode *application*
/// across every widget is still an open item per `design.md` (most widgets
/// still reference `AppPalette`'s light-only constants directly rather than
/// theme-aware `colorScheme` roles), but the token values themselves are now
/// accurate, not invented.
class AppTheme {
  const AppTheme._();

  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  static ColorScheme _colorScheme(Brightness brightness) {
    if (brightness == Brightness.light) {
      return const ColorScheme.light(
        surface: AppPalette.surfaceCard,
        onSurface: AppPalette.ink,
        onSurfaceVariant: AppPalette.inkSecondary,
        surfaceContainerHighest: AppPalette.surfaceFill,
        surfaceContainerHigh: AppPalette.surfaceFill,
        surfaceContainer: AppPalette.surfaceCard,
        surfaceContainerLow: AppPalette.surfaceCard,
        outline: AppPalette.border,
        outlineVariant: AppPalette.borderStrong,
        primary: AppPalette.ink,
        onPrimary: AppPalette.surfaceCard,
        secondary: AppPalette.inkSecondary,
        onSecondary: AppPalette.surfaceCard,
        tertiary: AppPalette.inkMuted,
        onTertiary: AppPalette.surfaceCard,
        error: AppPalette.dangerText,
        onError: AppPalette.surfaceCard,
        errorContainer: AppPalette.dangerBg,
        onErrorContainer: AppPalette.dangerText,
        inverseSurface: AppPalette.ink,
        onInverseSurface: AppPalette.surfaceCard,
      );
    }
    // Real dark tokens, handoff §2 — not a derived inversion.
    const darkPage = Color(0xFF131513);
    const darkCard = Color(0xFF1B1E1B);
    const darkFill = Color(0xFF242723);
    const darkBorder = Color(0xFF2C302C);
    const darkBorderStrong = Color(0xFF3D423C);
    const darkInk = Color(0xFFE9EBE8);
    const darkInkSecondary = Color(0xFFA2A8A0);
    const darkInkMuted = Color(0xFF767C75);
    const darkDangerText = Color(0xFFE58A7E);
    const darkDangerBg = Color(0xFF34201D);
    return const ColorScheme.dark(
      surface: darkCard,
      onSurface: darkInk,
      onSurfaceVariant: darkInkSecondary,
      surfaceContainerHighest: darkFill,
      surfaceContainerHigh: darkFill,
      surfaceContainer: darkCard,
      surfaceContainerLow: darkPage,
      outline: darkBorder,
      outlineVariant: darkBorderStrong,
      primary: darkInk,
      onPrimary: darkPage,
      secondary: darkInkSecondary,
      onSecondary: darkPage,
      tertiary: darkInkMuted,
      onTertiary: darkPage,
      error: darkDangerText,
      onError: darkPage,
      errorContainer: darkDangerBg,
      onErrorContainer: darkDangerText,
      inverseSurface: darkInk,
      onInverseSurface: darkPage,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final colorScheme = _colorScheme(brightness);
    final pageBackground =
        brightness == Brightness.light ? AppPalette.surfacePage : const Color(0xFF131513);
    final textTheme = AppTypography.buildTextTheme(colorScheme);
    final semanticColors =
        brightness == Brightness.light ? AppSemanticColors.light : AppSemanticColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: pageBackground,
      extensions: [semanticColors],

      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.screenCard),
          side: BorderSide(color: colorScheme.outline, width: 0.5),
        ),
      ),

      appBarTheme: AppBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        actionsIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonsPills)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(64, 44),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonsPills)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(64, 44),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonsPills)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: textTheme.labelLarge,
          foregroundColor: colorScheme.primary,
        ),
      ),

      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.buttonsPills),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.buttonsPills),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.buttonsPills),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.buttonsPills),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        side: BorderSide.none,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
        actionTextColor: colorScheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.screenCard)),
        insetPadding: const EdgeInsets.all(16),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.screenCard)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        elevation: 3,
      ),
    );
  }
}
