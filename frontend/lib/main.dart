import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'core/web/invite_redirect_cleanup_stub.dart'
    if (dart.library.html) 'core/web/invite_redirect_cleanup_web.dart';
import 'data/models/auth_session.dart';
import 'data/repositories/anomaly_repository.dart';
import 'data/repositories/assistant_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/connection_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/extended_finance_repository.dart';
import 'data/repositories/household_repository.dart';

/// Detects Supabase's invite-redirect landing URL: our own invite id as a
/// `?invite=` query param (added by the backend's redirect_to), plus
/// Supabase's own session tokens appended as a `#access_token=...&type=invite`
/// fragment. Query and fragment coexist fine on the same URL — this is
/// deliberate so it needs no change to the app's existing hash-based routing.
({String inviteId, AuthSession session})? _parseInviteRedirect(Uri uri) {
  final inviteId = uri.queryParameters['invite'];
  if (inviteId == null || uri.fragment.isEmpty) return null;

  final fragment = Uri.splitQueryString(uri.fragment);
  if (fragment['type'] != 'invite' || fragment['access_token'] == null) {
    return null;
  }

  return (
    inviteId: inviteId,
    session: AuthSession.fromInviteRedirectFragment(fragment),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  final authRepository = AuthRepository();
  final householdRepository = HouseholdRepository(
    authRepository: authRepository,
  );
  final connectionRepository = ConnectionRepository(
    authRepository: authRepository,
  );
  final dashboardRepository = DashboardRepository(
    authRepository: authRepository,
  );
  final financeRepository = ExtendedFinanceRepository(
    authRepository: authRepository,
  );
  final anomalyRepository = AnomalyRepository(authRepository: authRepository);
  final assistantRepository = AssistantRepository(authRepository: authRepository);

  final inviteRedirect = _parseInviteRedirect(Uri.base);
  var initialLocation = '/splash';

  if (inviteRedirect != null) {
    await authRepository.applyInviteSession(inviteRedirect.session);
    await authRepository.restoreSession();
    initialLocation = '/accept-invite?invite=${inviteRedirect.inviteId}';
    // go_router reads the browser's real current URL on web, not just
    // initialLocation — must rewrite the address bar to a clean route
    // before buildRouter()/runApp() so it never sees Supabase's raw
    // #access_token=... fragment as a route path.
    cleanupInviteRedirectUrl('/#$initialLocation');
  } else {
    authRepository.restoreSession();
  }

  runApp(
    FamilyFinanceApp(
      router: buildRouter(
        authRepository: authRepository,
        householdRepository: householdRepository,
        connectionRepository: connectionRepository,
        dashboardRepository: dashboardRepository,
        financeRepository: financeRepository,
        anomalyRepository: anomalyRepository,
        assistantRepository: assistantRepository,
        initialLocation: initialLocation,
      ),
    ),
  );
}
