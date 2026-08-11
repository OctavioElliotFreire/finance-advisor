import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_layout.dart';
import '../core/theme/app_spacing.dart';
import '../data/repositories/household_repository.dart';
import '../data/scope_controller.dart';
import '../ui/core/widgets/member_filter_chips.dart';
import '../ui/core/widgets/period_pill.dart';

/// Exposes the household's [ScopeController] to every descendant of
/// [HouseholdShell] (the 4 tab screens) without threading it through each
/// view's constructor — `AccountsView`/`AnalyticsView` read it locally via
/// [HouseholdScope.of] to decide their own sub-segment period visibility
/// (Saldos/Investimentos never show the period control, per `design.md`'s
/// Global Scope table), rather than the shell needing to know about every
/// screen's internal segments.
class HouseholdScope extends InheritedNotifier<ScopeController> {
  const HouseholdScope({super.key, required ScopeController controller, required super.child})
      : super(notifier: controller);

  static ScopeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HouseholdScope>();
    assert(scope != null, 'No HouseholdScope found above this context');
    return scope!.notifier!;
  }
}

/// Bottom-nav shell for the 4-tab restructure (Início/Contas/Análises/Família
/// per `design.md`'s spec), now also owning the household's [ScopeController]
/// and rendering the shared period-pill/member-chip header above
/// [navigationShell] per `design.md`'s Global Scope table — visibility keyed
/// off the active tab, since Família shows neither and Contas/Análises hide
/// the period row at the shell level (their own sub-segments decide it
/// locally; see [HouseholdScope]'s doc comment).
///
/// Responsive per `design.md`'s Web section (6a): below [kWideBreakpoint]
/// (1024px, matching the Grid section's own number — the single shared
/// constant every wide/narrow layout branch in the app now uses) this
/// renders the mobile bottom-nav pattern unchanged; at or above it, the
/// bottom [NavigationBar] is replaced by a [TopBarNav] strip (brand ·
/// inline nav · period pill),
/// with member chips in their own strip beneath, per spec order.
///
/// Known simplification: each of the 4 tab screens still renders its own
/// `Scaffold`/`AppBar` underneath this strip (title, and on Início a row of
/// action icons) — fully unifying into one merged top bar per the mockup
/// would mean threading a "suppress my own AppBar" signal into all 4 screens,
/// a larger refactor than the nav-chrome swap this covers. The web top bar
/// also omits the theme toggle and avatar the mockup shows — dark-mode
/// *application* is deliberately deferred (see `design.md`'s Open Questions),
/// and no settings screen or user-menu concept exists anywhere in the shell
/// today for an avatar to open.
class HouseholdShell extends StatefulWidget {
  const HouseholdShell({
    super.key,
    required this.navigationShell,
    required this.householdId,
    required this.householdRepository,
  });

  final StatefulNavigationShell navigationShell;
  final String householdId;
  final HouseholdRepository householdRepository;

  @override
  State<HouseholdShell> createState() => _HouseholdShellState();
}

// Shell-level visibility per design.md's Global Scope table. Contas and
// Análises show the member row here but decide period visibility locally
// (Saldos/Investimentos never show it) — see HouseholdScope's doc comment.
const _showsPeriodAtShell = {0: true, 1: false, 2: false, 3: false};
const _showsMembers = {0: true, 1: true, 2: true, 3: false};

/// design.md's Grid section: "Below 1024px, collapse to the mobile
/// single-column stack" — the same number governs this shell's own
/// bottom-nav-vs-top-bar switch. Distinct from `dashboard_view.dart`'s
/// unrelated `_wideLayoutBreakpoint` (720px), which splits that one
/// screen's own content into two columns, not shell-level nav.
class _NavDestinationSpec {
  const _NavDestinationSpec({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

// Single source of truth for both the mobile NavigationBar and the wide
// TopBarNav, so the two layouts can never drift out of sync with each
// other's labels/icons.
const _destinations = [
  _NavDestinationSpec(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Início'),
  _NavDestinationSpec(
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    label: 'Contas',
  ),
  _NavDestinationSpec(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Análises'),
  _NavDestinationSpec(icon: Icons.groups_outlined, selectedIcon: Icons.groups, label: 'Família'),
];

class _HouseholdShellState extends State<HouseholdShell> {
  late final ScopeController _scopeController = ScopeController(
    householdId: widget.householdId,
  )..load();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.householdRepository.listMembers(widget.householdId);
      if (mounted) _scopeController.setMembers(members);
    } catch (_) {
      // Member chips just degrade to an empty row — not worth a full error
      // banner for a secondary scoping control.
    }
  }

  @override
  void dispose() {
    _scopeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    final showPeriod = _showsPeriodAtShell[index] ?? false;
    final showMembers = _showsMembers[index] ?? false;

    void onDestinationSelected(int i) =>
        navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);

    return HouseholdScope(
      controller: _scopeController,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= kWideBreakpoint;

          return Scaffold(
            body: Column(
              children: [
                if (isWide)
                  ListenableBuilder(
                    listenable: _scopeController,
                    builder: (context, _) => Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TopBarNav(
                            currentIndex: index,
                            onDestinationSelected: onDestinationSelected,
                            showPeriod: showPeriod,
                            periodPill: PeriodPill(controller: _scopeController),
                          ),
                          if (showMembers) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _MemberChipsRow(controller: _scopeController),
                          ],
                        ],
                      ),
                    ),
                  )
                else if (showPeriod || showMembers)
                  ListenableBuilder(
                    listenable: _scopeController,
                    builder: (context, _) => Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (showPeriod) PeriodPill(controller: _scopeController),
                          if (showPeriod && showMembers) const SizedBox(height: AppSpacing.sm),
                          if (showMembers) _MemberChipsRow(controller: _scopeController),
                        ],
                      ),
                    ),
                  ),
                Expanded(child: widget.navigationShell),
              ],
            ),
            bottomNavigationBar: isWide
                ? null
                : NavigationBar(
                    selectedIndex: index,
                    onDestinationSelected: onDestinationSelected,
                    destinations: [
                      for (final d in _destinations)
                        NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
                    ],
                  ),
          );
        },
      ),
    );
  }

  StatefulNavigationShell get navigationShell => widget.navigationShell;
}

class _MemberChipsRow extends StatelessWidget {
  const _MemberChipsRow({required this.controller});

  final ScopeController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: MemberFilterChips(
        members: [
          for (var i = 0; i < controller.members.length; i++)
            MemberFilterOption(
              id: controller.members[i].id,
              label: controller.members[i].email,
              color: AppMemberColors.forIndex(i),
              selected: controller.selectedMemberIds.isEmpty ||
                  controller.selectedMemberIds.contains(controller.members[i].id),
            ),
        ],
        onToggle: controller.toggleMember,
      ),
    );
  }
}

/// Web top-bar nav per `design.md`'s §6a — brand · inline destination labels
/// · period pill (only when [showPeriod]). Deliberately decoupled from
/// [StatefulNavigationShell] (plain [currentIndex]/[onDestinationSelected]
/// params instead) so it's unit-testable without a real `go_router` shell —
/// see `test/app/top_bar_nav_test.dart`.
class TopBarNav extends StatelessWidget {
  const TopBarNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.showPeriod,
    required this.periodPill,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool showPeriod;
  final Widget periodPill;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Family Finance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: AppSpacing.lg),
        // Scrolls rather than overflows if the destination labels (plus
        // brand mark and period pill) ever don't fit — e.g. a browser
        // window resized right at the wide/narrow breakpoint, or larger
        // system font scaling. Still pins the period pill to the right
        // edge of the bar: this Expanded absorbs all remaining flexible
        // space, so the pill sitting right after it lands at the row's
        // end regardless of how much of that space the labels fill.
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: InkWell(
                      onTap: () => onDestinationSelected(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Text(
                          _destinations[i].label,
                          style: TextStyle(
                            fontWeight: i == currentIndex ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (showPeriod) periodPill,
      ],
    );
  }
}
