import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/household_shell.dart';
import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/dashboard.dart';
import 'package:frontend/data/models/extended_finance.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/dashboard_repository.dart';
import 'package:frontend/data/repositories/extended_finance_repository.dart';
import 'package:frontend/data/scope_controller.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';
import 'package:frontend/ui/core/widgets/period_pill.dart';
import 'package:frontend/ui/features/analytics/views/analytics_view.dart';

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

class _FakeBackendService extends BackendApiService {
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
    return Dashboard(
      householdName: 'Test Family',
      accounts: const [],
      totalBalance: 0,
      recentTransactions: const [],
      monthlyCashFlow: const [
        MonthlyCashFlow(month: '2026-07', income: 1000, expenses: 400, net: 600),
      ],
      syncStatus: const SyncStatus(status: null, updatedAt: null),
    );
  }

  @override
  Future<List<InvestmentSummary>> getInvestments(
    String accessToken,
    String householdId, {
    List<String>? memberIds,
  }) async => const [];

  @override
  Future<List<LoanSummary>> getLoans(
    String accessToken,
    String householdId, {
    List<String>? memberIds,
  }) async => const [];

  @override
  Future<List<CreditCardBillSummary>> getCreditCardBills(
    String accessToken,
    String householdId, {
    List<String>? memberIds,
  }) async => const [];

  @override
  Future<List<BalancePoint>> getBalanceHistory(
    String accessToken,
    String householdId, {
    int days = 90,
    List<String>? memberIds,
  }) async => const [];

  @override
  Future<List<CategoryBreakdownItem>> getCategoryBreakdown(
    String accessToken,
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memberIds,
    bool comparePrevious = false,
  }) async {
    return [
      CategoryBreakdownItem(
        category: 'Mercado',
        total: 180,
        previousTotal: comparePrevious ? 150 : null,
      ),
    ];
  }

  @override
  Future<List<MemberMonthlySpend>> getSpendingByMember(
    String accessToken,
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memberIds,
  }) async => const [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<(DashboardRepository, ExtendedFinanceRepository)> buildRepositories() async {
    final backendService = _FakeBackendService();
    final authRepository = AuthRepository(
      authService: _FakeAuthService(),
      backendService: backendService,
      storage: _FakeStorage(),
    );
    await authRepository.login('owner@example.com', 'hunter22');
    return (
      DashboardRepository(authRepository: authRepository, backendService: backendService),
      ExtendedFinanceRepository(authRepository: authRepository, backendService: backendService),
    );
  }

  testWidgets('shows the period pill on Gastos but not on Investimentos', (tester) async {
    final (dashboardRepository, financeRepository) = await buildRepositories();
    final scope = ScopeController(householdId: 'household-1');

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: AnalyticsView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            householdId: 'household-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PeriodPill), findsOneWidget);

    await tester.tap(find.text('Investimentos'));
    await tester.pumpAndSettle();

    expect(find.byType(PeriodPill), findsNothing);
  });

  testWidgets('shows a delta line for a category once compare-previous is on', (tester) async {
    final (dashboardRepository, financeRepository) = await buildRepositories();
    final scope = ScopeController(householdId: 'household-1');

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: AnalyticsView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            householdId: 'household-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mercado'), findsOneWidget);
    expect(find.textContaining('vs período anterior'), findsNothing);

    scope.setComparePrevious(true);
    await tester.pumpAndSettle();

    expect(find.text('+20% vs período anterior'), findsOneWidget);
  });
}
