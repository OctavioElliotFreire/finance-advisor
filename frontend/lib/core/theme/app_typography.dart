import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tokens per `design.md`'s handoff-driven spec
/// (`handoff-app-financas-familiar.md` §2): UI text is **Instrument Sans**
/// (400/500), numerals are a monospace tabular face — the doc's first choice
/// is **Geist Mono** with **IBM Plex Mono** as the named fallback. Geist Mono
/// isn't in the pinned `google_fonts` 6.3.3 catalog (checked directly against
/// the package source — no `geistMono` entry exists), so this uses the named
/// fallback, not a substitution of convenience.
///
/// The type scale below is the handoff's real explicit scale — NOT the
/// Material default scale used before (`displayLarge` 40px etc). The handoff
/// gives only 5 non-money roles (Screen title 15/20, Body 13/18, Label 12/16,
/// Caption 11/15, Nav 10/13) and is explicit that "no sizes between 13 and
/// 17" should exist. Flutter's [TextTheme] has 15 slots; this collapses
/// Material's upper roles (display*/headlineLarge/headlineMedium/titleLarge)
/// flat onto "Screen title" (nothing in this app needs anything bigger — a
/// deliberate choice, not an oversight), and fills titleSmall/labelLarge at
/// Body size + weight 500 so a "title" reads as emphasized without
/// introducing a forbidden in-between size.
class AppTypography {
  const AppTypography._();

  static String get fontFamily => GoogleFonts.instrumentSans().fontFamily!;

  static TextTheme buildTextTheme(ColorScheme colorScheme) {
    // Named per the handoff's roles, mapped onto Material's TextTheme slots.
    final screenTitle = _sans(15, 20, FontWeight.w500, colorScheme.onSurface);
    final body = _sans(13, 18, FontWeight.w400, colorScheme.onSurface);
    final bodyEmphasis = _sans(13, 18, FontWeight.w500, colorScheme.onSurface);
    final label = _sans(12, 16, FontWeight.w400, colorScheme.onSurfaceVariant);
    final caption = _sans(11, 15, FontWeight.w400, colorScheme.onSurfaceVariant);
    final nav = _sans(10, 13, FontWeight.w400, colorScheme.onSurfaceVariant);

    return TextTheme(
      displayLarge: screenTitle,
      displayMedium: screenTitle,
      displaySmall: screenTitle,
      headlineLarge: screenTitle,
      headlineMedium: screenTitle,
      headlineSmall: screenTitle,
      titleLarge: screenTitle,
      titleMedium: screenTitle,
      titleSmall: bodyEmphasis,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: bodyEmphasis,
      labelMedium: label,
      labelSmall: nav,
    );
  }

  static TextStyle _sans(double size, double height, FontWeight weight, Color color) {
    return GoogleFonts.instrumentSans(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle _mono(double size, double height, FontWeight weight) {
    return GoogleFonts.ibmPlexMono(
      fontSize: size,
      height: height / size,
      fontWeight: weight,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Money hero — dashboard/Início hero total.
  static TextStyle get amountLarge => _mono(30, 34, FontWeight.w500);

  /// Money medium — per-account balances, card-level totals.
  static TextStyle get amountMedium => _mono(17, 22, FontWeight.w500);

  /// Money inline — transaction-list trailing amount, chart tooltips.
  static TextStyle get amountSmall => _mono(13, 18, FontWeight.w400);
}
