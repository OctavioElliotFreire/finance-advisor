import 'package:flutter/material.dart';

/// Chart color tokens shared by every `fl_chart` consumer, so bar/line/pie
/// series pull from one source instead of each chart declaring its own
/// hardcoded palette.
class AppChartColors {
  const AppChartColors._();

  /// Fixed categorical order lifted verbatim from the original
  /// `category_breakdown_chart.dart` (dataviz skill's validated palette) —
  /// assigned deterministically per category name via `categoricalColorFor`,
  /// not by rank, so a category keeps its color as spending shifts.
  static const List<Color> categoricalPalette = [
    Color(0xFF2A78D6), // blue
    Color(0xFFEB6834), // orange
    Color(0xFF1BAF7A), // aqua
    Color(0xFFEDA100), // yellow
    Color(0xFFE87BA4), // magenta
  ];

  /// Deterministic label -> color mapping, unchanged from the original
  /// `_colorForCategory` hashing so no existing category's color shifts.
  /// "Other" is special-cased to [other] rather than hashed into the palette.
  static Color categoricalColorFor(BuildContext context, String label) {
    if (label == 'Other') return other(context);
    return categoricalPalette[label.hashCode.abs() % categoricalPalette.length];
  }

  /// Income bars — `ink-muted`, per the handoff's "income as bars (ink-muted)"
  /// cash-flow spec. Never green: there is no success/positive color in this
  /// design (`design.md`).
  static Color income(BuildContext context) => Theme.of(context).colorScheme.tertiary;

  /// Spending/expenses line — `ink` by default. Only the *crossover* segment
  /// (where spending exceeds income) renders in danger color — that's a
  /// per-segment chart detail the caller applies, not this helper's job.
  static Color expenses(BuildContext context) => Theme.of(context).colorScheme.onSurface;

  /// Theme-aware neutral for the "Other" category slice — replaces a
  /// hardcoded `Color(0xFF898781)` that read muddy in dark mode.
  static Color other(BuildContext context) => Theme.of(context).colorScheme.outlineVariant;
}
