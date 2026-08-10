import 'package:go_router/go_router.dart';

import '../data/repositories/anomaly_repository.dart';
import '../data/repositories/assistant_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/connection_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/extended_finance_repository.dart';
import '../data/repositories/household_repository.dart';
import '../ui/core/views/splash_view.dart';
import '../ui/features/accounts/views/accounts_view.dart';
import '../ui/features/analytics/views/analytics_view.dart';
import '../ui/features/anomalies/views/anomalies_view.dart';
import '../ui/features/assistant/views/assistant_view.dart';
import '../ui/features/auth/views/login_view.dart';
import '../ui/features/auth/views/register_view.dart';
import '../ui/features/connections/views/connections_view.dart';
import '../ui/features/dashboard/views/dashboard_view.dart';
import '../ui/features/family/views/family_view.dart';
import '../ui/features/finances/views/finances_view.dart';
import '../ui/features/households/views/household_list_view.dart';
import '../ui/features/households/views/member_access_view.dart';
import '../ui/features/households/views/members_view.dart';
import '../ui/features/invites/views/accept_invite_view.dart';
import 'household_shell.dart';

GoRouter buildRouter({
  required AuthRepository authRepository,
  required HouseholdRepository householdRepository,
  required ConnectionRepository connectionRepository,
  required DashboardRepository dashboardRepository,
  required ExtendedFinanceRepository financeRepository,
  required AnomalyRepository anomalyRepository,
  required AssistantRepository assistantRepository,
  String initialLocation = '/splash',
}) {
  return GoRouter(
    initialLocation: initialLocation,
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
        path: '/accept-invite',
        builder: (context, state) => AcceptInviteView(
          authRepository: authRepository,
          householdRepository: householdRepository,
          inviteId: state.uri.queryParameters['invite'] ?? '',
          onAccepted: (householdId, householdName) => context.go('/households/$householdId/home'),
        ),
      ),
      GoRoute(
        path: '/households',
        builder: (context, state) => HouseholdListView(
          householdRepository: householdRepository,
          onLogout: () => authRepository.logout(),
          onHouseholdSelected: (household) {
            context.go('/households/${household.id}/home');
          },
        ),
      ),
      GoRoute(
        path: '/households/:householdId',
        // Ancestor GoRoute.redirect callbacks run for descendant matches too
        // (go_router evaluates every route in the matched stack, not just the
        // leaf) — an earlier unconditional version of this redirect bounced
        // every /accounts, /analytics, /family navigation straight back to
        // /home. Only redirect when the location is exactly this parent path
        // (no sub-path yet), so the nested shell branches are left alone.
        redirect: (context, state) {
          // Segment-count check, not a string-equality check against
          // matchedLocation — that comparison was tried first and never
          // evaluated false for child paths in practice (i.e. it kept
          // redirecting every /accounts, /analytics, /family hit straight
          // back to /home), so don't reintroduce it without re-verifying
          // against a real browser first.
          final segments = state.uri.pathSegments;
          if (segments.length <= 2) {
            final householdId = state.pathParameters['householdId'];
            return '/households/$householdId/home';
          }
          return null;
        },
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) => HouseholdShell(navigationShell: navigationShell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'home',
                    builder: (context, state) {
                      final householdId = state.pathParameters['householdId']!;
                      return DashboardView(
                        dashboardRepository: dashboardRepository,
                        householdId: householdId,
                        householdName: 'Família',
                        onManageConnections: () => context.push('/households/$householdId/connections'),
                        onViewFinances: () => context.push('/households/$householdId/finances'),
                        onViewAnomalies: () => context.push('/households/$householdId/anomalies'),
                        onManageMembers: () => context.push('/households/$householdId/members'),
                        onOpenAssistant: () => context.push('/households/$householdId/assistant'),
                      );
                    },
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'accounts',
                    builder: (context, state) => AccountsView(
                      dashboardRepository: dashboardRepository,
                      householdId: state.pathParameters['householdId']!,
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'analytics',
                    builder: (context, state) => AnalyticsView(
                      dashboardRepository: dashboardRepository,
                      financeRepository: financeRepository,
                      householdId: state.pathParameters['householdId']!,
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: 'family',
                    builder: (context, state) => FamilyView(
                      householdRepository: householdRepository,
                      connectionRepository: connectionRepository,
                      householdId: state.pathParameters['householdId']!,
                      currentUserEmail: authRepository.currentUser?.email,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/households/:householdId/assistant',
        builder: (context, state) => AssistantView(
          assistantRepository: assistantRepository,
          householdId: state.pathParameters['householdId']!,
          householdName: state.extra as String? ?? 'Família',
        ),
      ),
      GoRoute(
        path: '/households/:householdId/members',
        builder: (context, state) {
          final householdId = state.pathParameters['householdId']!;
          final householdName = state.extra as String? ?? 'Família';
          return MembersView(
            householdRepository: householdRepository,
            householdId: householdId,
            householdName: householdName,
            currentUserEmail: authRepository.currentUser?.email,
            onManageAccess: (memberId, memberEmail) => context.push(
              '/households/$householdId/members/$memberId/access',
              extra: memberEmail,
            ),
          );
        },
      ),
      GoRoute(
        path: '/households/:householdId/members/:memberId/access',
        builder: (context, state) => MemberAccessView(
          householdRepository: householdRepository,
          householdId: state.pathParameters['householdId']!,
          memberId: state.pathParameters['memberId']!,
          memberEmail: state.extra as String? ?? 'Membro',
        ),
      ),
      GoRoute(
        path: '/households/:householdId/connections',
        builder: (context, state) => ConnectionsView(
          connectionRepository: connectionRepository,
          householdId: state.pathParameters['householdId']!,
          householdName: state.extra as String? ?? 'Família',
          currentUserEmail: authRepository.currentUser?.email,
        ),
      ),
      GoRoute(
        path: '/households/:householdId/finances',
        builder: (context, state) => FinancesView(
          financeRepository: financeRepository,
          householdId: state.pathParameters['householdId']!,
          householdName: state.extra as String? ?? 'Família',
        ),
      ),
      GoRoute(
        path: '/households/:householdId/anomalies',
        builder: (context, state) => AnomaliesView(
          anomalyRepository: anomalyRepository,
          householdId: state.pathParameters['householdId']!,
          householdName: state.extra as String? ?? 'Família',
        ),
      ),
    ],
  );
}
