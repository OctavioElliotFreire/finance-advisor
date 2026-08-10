import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../data/repositories/household_repository.dart';
import '../data/models/household_member.dart';
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
/// Known simplification: this always renders the mobile bottom-nav pattern.
/// `design.md`'s Web section (6a) specifies a top-bar nav replacing the
/// bottom bar on wide screens — that responsive split isn't built yet, it's
/// flagged as follow-up rather than done here.
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

class _HouseholdShellState extends State<HouseholdShell> {
  late final ScopeController _scopeController = ScopeController(
    householdId: widget.householdId,
  )..load();

  List<HouseholdMember> _members = const [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.householdRepository.listMembers(widget.householdId);
      if (mounted) setState(() => _members = members);
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

    return HouseholdScope(
      controller: _scopeController,
      child: Scaffold(
        body: Column(
          children: [
            if (showPeriod || showMembers)
              ListenableBuilder(
                listenable: _scopeController,
                builder: (context, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (showPeriod) PeriodPill(controller: _scopeController),
                      if (showPeriod && showMembers) const SizedBox(height: AppSpacing.sm),
                      if (showMembers)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: MemberFilterChips(
                            members: [
                              for (var i = 0; i < _members.length; i++)
                                MemberFilterOption(
                                  id: _members[i].id,
                                  label: _members[i].email,
                                  color: AppMemberColors.forIndex(i),
                                  selected: _scopeController.selectedMemberIds.isEmpty ||
                                      _scopeController.selectedMemberIds.contains(_members[i].id),
                                ),
                            ],
                            onToggle: _scopeController.toggleMember,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(child: widget.navigationShell),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) =>
              navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Contas',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Análises',
            ),
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Família'),
          ],
        ),
      ),
    );
  }

  StatefulNavigationShell get navigationShell => widget.navigationShell;
}
