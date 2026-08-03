import 'package:go_router/go_router.dart';

import '../data/repositories/anomaly_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/connection_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/extended_finance_repository.dart';
import '../data/repositories/household_repository.dart';
import '../ui/core/views/splash_view.dart';
import '../ui/features/anomalies/views/anomalies_view.dart';
import '../ui/features/auth/views/login_view.dart';
import '../ui/features/auth/views/register_view.dart';
import '../ui/features/connections/views/connections_view.dart';
import '../ui/features/dashboard/views/dashboard_view.dart';
import '../ui/features/finances/views/finances_view.dart';
import '../ui/features/households/views/household_list_view.dart';
import '../ui/features/households/views/members_view.dart';

GoRouter buildRouter({
  required AuthRepository authRepository,
  required HouseholdRepository householdRepository,
  required ConnectionRepository connectionRepository,
  required DashboardRepository dashboardRepository,
  required ExtendedFinanceRepository financeRepository,
  required AnomalyRepository anomalyRepository,
}) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authRepository,
    redirect: (context, state) {
      final loggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (authRepository.isRestoring) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }
      if (!authRepository.isAuthenticated) {
        return loggingIn ? null : '/login';
      }
      if (loggingIn || state.matchedLocation == '/splash') {
        return '/households';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashView()),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginView(
          authRepository: authRepository,
          onLoggedIn: () => context.go('/households'),
          onNavigateToRegister: () => context.go('/register'),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterView(
          authRepository: authRepository,
          onRegistered: () => context.go('/households'),
          onNavigateToLogin: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/households',
        builder: (context, state) => HouseholdListView(
          householdRepository: householdRepository,
          onLogout: () => authRepository.logout(),
          onHouseholdSelected: (household) {
            context.push('/households/${household.id}/dashboard', extra: household.name);
          },
        ),
      ),
      GoRoute(
        path: '/households/:householdId/dashboard',
        builder: (context, state) {
          final householdId = state.pathParameters['householdId']!;
          final householdName = state.extra as String? ?? 'Household';
          return DashboardView(
            dashboardRepository: dashboardRepository,
            householdId: householdId,
            householdName: householdName,
            onManageConnections: () => context.push(
              '/households/$householdId/connections',
              extra: householdName,
            ),
            onViewFinances: () => context.push(
              '/households/$householdId/finances',
              extra: householdName,
            ),
            onViewAnomalies: () => context.push(
              '/households/$householdId/anomalies',
              extra: householdName,
            ),
            onManageMembers: () => context.push(
              '/households/$householdId/members',
              extra: householdName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/households/:householdId/members',
        builder: (context, state) => MembersView(
          householdRepository: householdRepository,
          householdId: state.pathParameters['householdId']!,
          householdName: state.extra as String? ?? 'Household',
        ),
      ),
      GoRoute(
        path: '/households/:householdId/connections',
        builder: (context, state) => ConnectionsView(
          connectionRepository: connectionRepository,
          householdId: state.pathParameters['householdId']!,
          householdName: state.extra as String? ?? 'Household',
          currentUserEmail: authRepository.currentUser?.email,
        ),
      ),
      GoRoute(
        path: '/households/:householdId/finances',
        builder: (context, state) => FinancesView(
          financeRepository: financeRepository,
          householdId: state.pathParameters['householdId']!,
          householdName: state.extra as String? ?? 'Household',
        ),
      ),
      GoRoute(
        path: '/households/:householdId/anomalies',
        builder: (context, state) => AnomaliesView(
          anomalyRepository: anomalyRepository,
          householdId: state.pathParameters['householdId']!,
          householdName: state.extra as String? ?? 'Household',
        ),
      ),
    ],
  );
}
