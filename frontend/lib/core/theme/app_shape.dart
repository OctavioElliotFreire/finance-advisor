/// Corner-radius scale per `design.md`'s handoff-driven spec
/// (`handoff-app-financas-familiar.md` §2) — a 5-tier scale, not the earlier
/// 3-tier `sm`/`md`/`lg` guess this file started with.
class AppRadius {
  const AppRadius._();

  /// Progress/track bars.
  static const double bar = 2;

  /// Buttons, text-input fields, and pill-shaped controls (segmented control).
  static const double buttonsPills = 8;

  /// Inner/nested cards (a smaller surface inside a screen card).
  static const double innerCard = 12;

  /// Screen-level cards, sheets, dialogs.
  static const double screenCard = 16;

  /// Chips (member filter chips, category pills).
  static const double chip = 20;
}
