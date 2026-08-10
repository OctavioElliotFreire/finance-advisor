import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/household_shell.dart';
import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/dashboard.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/dashboard_repository.dart';
import 'package:frontend/data/scope_controller.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';
import 'package:frontend/ui/features/dashboard/views/dashboard_view.dart';

class _FakeAuthService extends SupabaseAuthService {
  @override
  Future<AuthSession> signIn(String email, String password) async {
    return AuthSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      userId: 'user-1',
      email: email,
    );
  }
}

class _FakeStorage extends SecureTokenStorage {
  @override
  Future<void> saveSession(AuthSession session) async {}

  @override
  Future<AuthSession?> readSession() async => null;

  @override
  Future<void> clear() async {}
}

class _SpyBackendService extends BackendApiService {
  final List<List<String>?> memberIdsCalls = [];

  @override
  Future<Me> getMe(String accessToken) async {
    return Me(id: 'user-1', email: 'owner@example.com', createdAt: DateTime.now().toUtc());
  }

  @override
  Future<Dashboard> getDashboard(
    String accessToken,
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memberIds,
  }) async {
    memberIdsCalls.add(memberIds);
    return Dashboard(
      householdName: 'Test Family',
      accounts: const [],
      totalBalance: 0,
      recentTransactions: const [],
      monthlyCashFlow: const [],
      syncStatus: const SyncStatus(status: null, updatedAt: null),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<DashboardRepository> buildRepository(_SpyBackendService backendService) async {
    final authRepository = AuthRepository(
      authService: _FakeAuthService(),
      backendService: backendService,
      storage: _FakeStorage(),
    );
    await authRepository.login('owner@example.com', 'hunter22');
    return DashboardRepository(authRepository: authRepository, backendService: backendService);
  }

  testWidgets('loads with no member filter by default', (tester) async {
    final backendService = _SpyBackendService();
    final repository = await buildRepository(backendService);
    final scope = ScopeController(householdId: 'household-1');

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: DashboardView(
            dashboardRepository: repository,
            householdId: 'household-1',
            householdName: 'Test Family',
            onManageConnections: () {},
            onViewFinances: () {},
            onViewAnomalies: () {},
            onManageMembers: () {},
            onOpenAssistant: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(backendService.memberIdsCalls, [null]);
  });

  testWidgets('reloads with the selected member id when the scope changes', (tester) async {
    final backendService = _SpyBackendService();
    final repository = await buildRepository(backendService);
    final scope = ScopeController(householdId: 'household-1');

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: DashboardView(
            dashboardRepository: repository,
            householdId: 'household-1',
            householdName: 'Test Family',
            onManageConnections: () {},
            onViewFinances: () {},
            onViewAnomalies: () {},
            onManageMembers: () {},
            onOpenAssistant: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    scope.toggleMember('member-a');
    await tester.pumpAndSettle();

    expect(backendService.memberIdsCalls.last, ['member-a']);
  });
}
