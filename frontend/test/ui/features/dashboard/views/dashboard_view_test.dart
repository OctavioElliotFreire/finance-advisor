import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/household_shell.dart';
import 'package:frontend/data/models/anomaly.dart';
import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/dashboard.dart';
import 'package:frontend/data/models/extended_finance.dart';
import 'package:frontend/data/models/household_member.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/anomaly_repository.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/dashboard_repository.dart';
import 'package:frontend/data/repositories/extended_finance_repository.dart';
import 'package:frontend/data/scope_controller.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';
import 'package:frontend/ui/core/formatting/money.dart';
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

  @override
  Future<List<CreditCardBillSummary>> getCreditCardBills(
    String accessToken,
    String householdId, {
    List<String>? memberIds,
  }) async => const [];

  @override
  Future<List<MemberMonthlySpend>> getSpendingByMember(
    String accessToken,
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memberIds,
  }) async => const [];

  @override
  Future<List<AnomalySummary>> getAnomalies(
    String accessToken,
    String householdId, {
    String? statusFilter,
  }) async => const [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<(DashboardRepository, ExtendedFinanceRepository, AnomalyRepository)> buildRepositories(
    BackendApiService backendService,
  ) async {
    final authRepository = AuthRepository(
      authService: _FakeAuthService(),
      backendService: backendService,
      storage: _FakeStorage(),
    );
    await authRepository.login('owner@example.com', 'hunter22');
    return (
      DashboardRepository(authRepository: authRepository, backendService: backendService),
      ExtendedFinanceRepository(authRepository: authRepository, backendService: backendService),
      AnomalyRepository(authRepository: authRepository, backendService: backendService),
    );
  }

  testWidgets('loads with no member filter by default', (tester) async {
    final backendService = _SpyBackendService();
    final (dashboardRepository, financeRepository, anomalyRepository) = await buildRepositories(
      backendService,
    );
    final scope = ScopeController(householdId: 'household-1');

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: DashboardView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            anomalyRepository: anomalyRepository,
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
    final (dashboardRepository, financeRepository, anomalyRepository) = await buildRepositories(
      backendService,
    );
    final scope = ScopeController(householdId: 'household-1');

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: DashboardView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            anomalyRepository: anomalyRepository,
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

  testWidgets('renders hero, credit block, fatura warning, alerts, and per-member spend', (
    tester,
  ) async {
    final backendService = _PopulatedBackendService();
    final (dashboardRepository, financeRepository, anomalyRepository) = await buildRepositories(
      backendService,
    );
    final scope = ScopeController(householdId: 'household-1');
    scope.setMembers([
      HouseholdMember(
        id: 'member-a',
        appUserId: 'au-a',
        email: 'a@example.com',
        role: 'owner',
        createdAt: DateTime(2026, 1, 1),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: DashboardView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            anomalyRepository: anomalyRepository,
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

    expect(find.text('Gastos do mês'), findsOneWidget);
    expect(find.text(formatMoney(3200, 'BRL')), findsOneWidget);
    expect(find.text('Realizado · Comprometido ${formatMoney(5760, 'BRL')}'), findsOneWidget);
    expect(find.text('Entradas ${formatMoney(5000, 'BRL')}'), findsOneWidget);
    expect(find.text('Sobrou ${formatMoney(1800, 'BRL')}'), findsOneWidget);
    expect(find.text('Limite disponível'), findsOneWidget);
    expect(
      find.textContaining('de ${formatMoney(5000, 'BRL')} · 1 cartão'),
      findsOneWidget,
    );
    expect(find.textContaining('Fatura do C6'), findsOneWidget);
    expect(find.textContaining('cobranças incomuns'), findsOneWidget);
    expect(find.text('Por membro'), findsOneWidget);
    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.text(formatMoney(1500, 'BRL')), findsOneWidget);
    expect(find.textContaining('de 2 contas atualizadas'), findsOneWidget);
  });

  testWidgets('stays stacked at a width between the old (720) and corrected (1024) breakpoint', (
    tester,
  ) async {
    // Regression guard: Início's two-column split used to key off its own
    // local 720px breakpoint, independent of household_shell.dart's 1024px
    // nav breakpoint. It now shares the same kWideBreakpoint (1024) — a
    // width in the 720-1023 range must show the mobile stacked layout,
    // not two columns like it would have before this fix.
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backendService = _PopulatedBackendService();
    final (dashboardRepository, financeRepository, anomalyRepository) = await buildRepositories(
      backendService,
    );
    final scope = ScopeController(householdId: 'household-1');
    scope.setMembers([
      HouseholdMember(
        id: 'member-a',
        appUserId: 'au-a',
        email: 'a@example.com',
        role: 'owner',
        createdAt: DateTime(2026, 1, 1),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: DashboardView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            anomalyRepository: anomalyRepository,
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

    final heroTop = tester.getTopLeft(find.text('Gastos do mês')).dy;
    final transactionsTop = tester.getTopLeft(find.text('Movimentações recentes')).dy;
    expect(transactionsTop, greaterThan(heroTop));
  });
}

class _PopulatedBackendService extends BackendApiService {
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
      accounts: const [
        AccountSummary(
          id: 'card-1',
          name: 'C6',
          type: 'CREDIT',
          subtype: null,
          balance: -580.90,
          currencyCode: 'BRL',
          creditLimit: 5000,
          availableCreditLimit: 3000,
        ),
      ],
      totalBalance: -580.90,
      recentTransactions: const [],
      monthlyCashFlow: const [
        MonthlyCashFlow(month: '2026-08', income: 5000, expenses: 3200, net: 1800),
      ],
      syncStatus: SyncStatus(
        status: 'completed',
        updatedAt: DateTime.now().toUtc(),
        syncedConnections: 1,
        totalConnections: 2,
      ),
    );
  }

  @override
  Future<List<CreditCardBillSummary>> getCreditCardBills(
    String accessToken,
    String householdId, {
    List<String>? memberIds,
  }) async {
    return [
      CreditCardBillSummary(
        id: 'bill-1',
        accountId: 'card-1',
        dueDate: DateTime.now().toUtc().add(const Duration(days: 3)),
        closingDate: DateTime.now().toUtc(),
        totalAmount: 5760,
        minimumPayment: 500,
        currencyCode: 'BRL',
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
  }) async {
    return const [MemberMonthlySpend(month: '2026-08', memberId: 'member-a', total: 1500)];
  }

  @override
  Future<List<AnomalySummary>> getAnomalies(
    String accessToken,
    String householdId, {
    String? statusFilter,
  }) async {
    return [
      AnomalySummary(
        id: 'a1',
        transactionId: null,
        householdMemberId: null,
        rule: 'duplicate_transaction',
        severity: 'medium',
        score: null,
        summary: 'Possível cobrança duplicada',
        status: 'open',
        explanation: null,
        explainedAt: null,
        createdAt: DateTime.now().toUtc(),
      ),
      AnomalySummary(
        id: 'a2',
        transactionId: null,
        householdMemberId: null,
        rule: 'duplicate_transaction',
        severity: 'medium',
        score: null,
        summary: 'Possível cobrança duplicada',
        status: 'open',
        explanation: null,
        explainedAt: null,
        createdAt: DateTime.now().toUtc(),
      ),
    ];
  }
}
