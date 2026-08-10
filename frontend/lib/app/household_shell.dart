import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav shell for the 4-tab restructure (Início/Contas/Análises/Família
/// per `design.md`'s spec). Wraps a [StatefulNavigationShell]
/// so each tab keeps its own navigation stack/scroll position when switching.
///
/// Known simplification: this always renders the mobile bottom-nav pattern.
/// `design.md`'s Web section (6a) specifies a top-bar nav replacing the
/// bottom bar on wide screens — that responsive split isn't built yet, it's
/// flagged as follow-up rather than done here.
class HouseholdShell extends StatelessWidget {
  const HouseholdShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
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
    );
  }
}
