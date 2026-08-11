import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// `design.md`'s §6a Grid section: "Below 1024px, collapse to the mobile
/// single-column stack." The single source of truth for every wide/narrow
/// layout branch in the app — before this existed, `household_shell.dart`
/// and `dashboard_view.dart` each kept their own local breakpoint constant
/// (1024 and 720 respectively) that had drifted out of sync with each
/// other and with this number.
const kWideBreakpoint = 1024.0;

/// §6a's Grid section: "Max container 1280px."
const kMaxContentWidth = 1280.0;

/// Wraps a screen's top-level scrollable content per §6a's Grid section:
/// centered, capped at [kMaxContentWidth], with 24px page padding
/// ([AppSpacing.xl]) at/above [kWideBreakpoint] and the existing mobile
/// 16px ([AppSpacing.lg]) below it. Takes `children` rather than a single
/// `child` so it's a near drop-in replacement for every tab screen's
/// existing `ListView(padding: ..., children: [...])` — and still nests
/// correctly under `RefreshIndicator` (`Center`/`ConstrainedBox` don't
/// introduce a new scroll boundary, so pull-to-refresh's notification
/// bubbling from the inner `ListView` is unaffected).
class AppGridPage extends StatelessWidget {
  const AppGridPage({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kWideBreakpoint;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: ListView(
              padding: EdgeInsets.all(isWide ? AppSpacing.xl : AppSpacing.lg),
              children: children,
            ),
          ),
        );
      },
    );
  }
}
