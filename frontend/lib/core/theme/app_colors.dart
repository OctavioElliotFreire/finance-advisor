import 'package:flutter/material.dart';

/// Flat design-system palette per `design.md`, corrected against
/// `handoff-app-financas-familiar.md` (the authoritative written handoff —
/// supersedes the raw `web-mockups.html` extraction this was first drafted
/// from). Replaces the earlier `Colors.teal` Material 3 seed — this is a
/// deliberately mostly-monochrome palette, not a seeded scheme, so every role
/// is spelled out explicitly rather than derived. Light tokens only — dark
/// equivalents live inline in [AppTheme] (dark-mode *application* across
/// every widget is still an open item per `design.md`, not just a token gap).
class AppPalette {
  const AppPalette._();

  // Surfaces
  static const Color surfacePage = Color(0xFFF7F8F6);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceFill = Color(0xFFEDEFEC);

  // Borders (hairline only — this design has no elevation/shadow)
  static const Color border = Color(0xFFE2E5E0);
  static const Color borderStrong = Color(0xFFCBCFC8);

  // Ink (text)
  static const Color ink = Color(0xFF191C19);
  static const Color inkSecondary = Color(0xFF565B55);
  static const Color inkMuted = Color(0xFF878D86);

  // Semantic state — warning/danger only. There is deliberately no
  // success/positive token: income and a healthy month are never green,
  // per the handoff's explicit "no positive/success color" principle.
  static const Color warningText = Color(0xFF8A5B14);
  static const Color warningBg = Color(0xFFFCF2DF);
  static const Color dangerText = Color(0xFFA63229);
  static const Color dangerBg = Color(0xFFFBEAE7);
}

/// Member-identity accent colors — one per household member, assigned by
/// join order via [AppMemberColors.forIndex]. These are identity colors, not
/// a general categorical chart palette (see [AppChartColors] for that).
///
/// Six is the ceiling (handoff §2): the 7th+ member folds into [outros] for
/// charting — they still appear individually in lists, just without a unique
/// chart color.
class AppMemberColors {
  const AppMemberColors._();

  static const List<Color> accents = [
    Color(0xFF6E63D2), // 1 — Roxo
    Color(0xFF0E8A86), // 2 — Teal
    Color(0xFFCE5528), // 3 — Laranja
    Color(0xFFB2497F), // 4 — Magenta
    Color(0xFF2F76B8), // 5 — Azul
    Color(0xFF8A7A1C), // 6 — Ocre
  ];

  static const Color outros = Color(0xFF9AA098);

  static Color forIndex(int index) =>
      index < accents.length ? accents[index] : outros;
}

/// Warning tokens Material's [ColorScheme] has no role for. Danger reuses
/// [ColorScheme.error]/[ColorScheme.errorContainer] directly (see
/// [AppTheme]) rather than a second bespoke pair here.
///
/// There is intentionally no `success`/`onSuccess`/`successContainer` field —
/// removed per the handoff's "no positive/success color at all" rule. If a
/// call site needs a "this is fine" signal, that's `StatusTone.neutral` (plain
/// ink), not a color — color means *person* or *problem*, never approval.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  static const AppSemanticColors light = AppSemanticColors(
    warning: AppPalette.warningText,
    onWarning: Color(0xFFFFFFFF),
    warningContainer: AppPalette.warningBg,
    onWarningContainer: AppPalette.warningText,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    warning: Color(0xFFE0B45C),
    onWarning: Color(0xFF302716),
    warningContainer: Color(0xFF302716),
    onWarningContainer: Color(0xFFE0B45C),
  );

  @override
  AppSemanticColors copyWith({
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return AppSemanticColors(
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
    );
  }
}

/// Reads the app's semantic-color extension, falling back to [AppSemanticColors.light]
/// if a theme without the extension is somehow in scope (should not happen once
/// [AppTheme.light]/[AppTheme.dark] are wired into `MaterialApp`).
extension AppSemanticColorsContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
