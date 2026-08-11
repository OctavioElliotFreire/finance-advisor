import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/household_shell.dart';
import 'package:frontend/core/theme/app_layout.dart';
import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/dashboard.dart';
import 'package:frontend/data/models/extended_finance.dart';
import 'package:frontend/data/models/household_member.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/dashboard_repository.dart';
import 'package:frontend/data/repositories/extended_finance_repository.dart';
import 'package:frontend/data/scope_controller.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/ui/core/formatting/money.dart';
import 'package:frontend/ui/features/accounts/views/accounts_view.dart';

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
    return const Dashboard(
      householdName: 'Test Family',
      accounts: [
        AccountSummary(
          id: 'checking-a',
          name: 'Conta Corrente A',
          type: 'BANK',
          subtype: 'CHECKING_ACCOUNT',
          balance: 1000,
          currencyCode: 'BRL',
          ownerMemberId: 'member-a',
          connectionStatus: 'UPDATED',
          number: '0001-9876543',
        ),
        AccountSummary(
          id: 'card-low-util',
          name: 'Cartão Baixo Uso',
          type: 'CREDIT',
          subtype: null,
          balance: -200,
          currencyCode: 'BRL',
          creditLimit: 10000,
          availableCreditLimit: 8000,
          ownerMemberId: 'member-a',
          connectionStatus: 'UPDATED',
        ),
        AccountSummary(
          id: 'card-high-util',
          name: 'Cartão Alto Uso',
          type: 'CREDIT',
          subtype: null,
          balance: -800,
          currencyCode: 'BRL',
          creditLimit: 1000,
          availableCreditLimit: 200,
          ownerMemberId: 'member-b',
          connectionStatus: 'UPDATED',
        ),
        AccountSummary(
          id: 'broken-account',
          name: 'Conta Sem Sincronizar',
          type: 'BANK',
          subtype: 'CHECKING_ACCOUNT',
          balance: 50,
          currencyCode: 'BRL',
          ownerMemberId: null,
          connectionStatus: 'LOGIN_ERROR',
        ),
      ],
      totalBalance: 50,
      recentTransactions: [],
      monthlyCashFlow: [],
      syncStatus: SyncStatus(status: null, updatedAt: null),
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
        id: 'bill-low',
        accountId: 'card-low-util',
        dueDate: DateTime.now().toUtc().add(const Duration(days: 10)),
        closingDate: DateTime.now().toUtc(),
        totalAmount: 2000,
        minimumPayment: 200,
        currencyCode: 'BRL',
      ),
    ];
  }

  @override
  Future<List<TransactionSummary>> listTransactions(
    String accessToken,
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memberIds,
    int limit = 50,
    int offset = 0,
  }) async {
    return [
      TransactionSummary(
        id: 'txn-income',
        accountId: 'checking-a',
        accountName: 'Conta Corrente A',
        description: 'Salário',
        amount: 5000,
        currencyCode: 'BRL',
        transactionDate: DateTime(2026, 8, 5),
        category: 'Renda',
      ),
      TransactionSummary(
        id: 'txn-flagged',
        accountId: 'card-low-util',
        accountName: 'Cartão Baixo Uso',
        description: 'Compra suspeita',
        amount: -300,
        currencyCode: 'BRL',
        transactionDate: DateTime(2026, 8, 6),
        category: 'Compras',
        isFlagged: true,
      ),
      TransactionSummary(
        id: 'txn-transfer',
        accountId: 'checking-a',
        accountName: 'Conta Corrente A',
        description: 'Transferência interna',
        amount: -150,
        currencyCode: 'BRL',
        transactionDate: DateTime(2026, 8, 4),
        category: null,
        isTransfer: true,
      ),
      TransactionSummary(
        id: 'txn-split',
        accountId: 'checking-a',
        accountName: 'Conta Corrente A',
        description: 'Supermercado',
        amount: -400,
        currencyCode: 'BRL',
        transactionDate: DateTime(2026, 8, 3),
        category: 'Lazer',
        splits: const [
          TransactionSplitItem(category: 'Mercado', amount: -300),
          TransactionSplitItem(category: 'Farmácia', amount: -100),
        ],
      ),
    ];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Saldos groups by member, colors utilization, and flags broken connections', (
    tester,
  ) async {
    final backendService = _FakeBackendService();
    final authRepository = AuthRepository(
      authService: _FakeAuthService(),
      backendService: backendService,
      storage: _FakeStorage(),
    );
    await authRepository.login('owner@example.com', 'hunter22');
    final dashboardRepository = DashboardRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    final financeRepository = ExtendedFinanceRepository(
      authRepository: authRepository,
      backendService: backendService,
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
      HouseholdMember(
        id: 'member-b',
        appUserId: 'au-b',
        email: 'b@example.com',
        role: 'member',
        createdAt: DateTime(2026, 1, 2),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: AccountsView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            householdId: 'household-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saldos'));
    await tester.pumpAndSettle();

    // Group headers, in member join order, Outros last.
    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.text('b@example.com'), findsOneWidget);
    expect(find.text('Outros'), findsOneWidget);

    // Checking account: balance as usual.
    expect(find.text('Conta Corrente A'), findsOneWidget);
    expect(find.text(formatMoney(1000, 'BRL')), findsOneWidget);

    // Credit cards: available-limit headline, not balance.
    expect(find.text(formatMoney(8000, 'BRL')), findsOneWidget);
    expect(find.text(formatMoney(200, 'BRL')), findsOneWidget);
    expect(find.text(formatMoney(-200, 'BRL')), findsNothing); // never the raw balance

    // Fatura line only appears for the card with a current bill.
    expect(find.textContaining('Fatura ${formatMoney(2000, 'BRL')}'), findsOneWidget);

    // Broken connection replaces the normal line entirely.
    expect(find.text('Conta Sem Sincronizar'), findsOneWidget);
    expect(find.text('Sem sincronizar'), findsOneWidget);

    // Utilization coloring: 20% -> not danger/warning, 80% -> danger (error color).
    final context = tester.element(find.text('Saldos'));
    final dangerColor = Theme.of(context).colorScheme.error;
    final warningColor = context.semanticColors.warning;

    final lowUtilText = tester.widget<Text>(find.text(formatMoney(8000, 'BRL')));
    final highUtilText = tester.widget<Text>(find.text(formatMoney(200, 'BRL')));

    expect(highUtilText.style?.color, dangerColor);
    expect(lowUtilText.style?.color, isNot(dangerColor));
    expect(lowUtilText.style?.color, isNot(warningColor));
  });

  testWidgets('Extrato groups by account, shows category/flag icon, and filter pills narrow the list', (
    tester,
  ) async {
    final backendService = _FakeBackendService();
    final authRepository = AuthRepository(
      authService: _FakeAuthService(),
      backendService: backendService,
      storage: _FakeStorage(),
    );
    await authRepository.login('owner@example.com', 'hunter22');
    final dashboardRepository = DashboardRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    final financeRepository = ExtendedFinanceRepository(
      authRepository: authRepository,
      backendService: backendService,
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
      HouseholdMember(
        id: 'member-b',
        appUserId: 'au-b',
        email: 'b@example.com',
        role: 'member',
        createdAt: DateTime(2026, 1, 2),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: AccountsView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            householdId: 'household-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Extrato is the default segment — no tap needed.
    expect(find.text('Extrato'), findsOneWidget);

    // Section headers, one per account, with masked number.
    expect(find.text('Conta Corrente A'), findsOneWidget);
    expect(find.text('Cartão Baixo Uso'), findsOneWidget);
    expect(find.text(formatMaskedAccountNumber('0001-9876543')), findsOneWidget);

    // Category renders on the row now.
    expect(find.textContaining('Renda'), findsOneWidget);
    expect(find.textContaining('Compras'), findsOneWidget);

    // Flag icon only on the flagged row.
    expect(find.byIcon(Icons.flag), findsOneWidget);

    // Sinalizados narrows to just the flagged transaction.
    await tester.tap(find.text('Sinalizados'));
    await tester.pumpAndSettle();
    expect(find.text('Compra suspeita'), findsOneWidget);
    expect(find.text('Salário'), findsNothing);

    // Entradas narrows to just the income transaction.
    await tester.tap(find.text('Entradas'));
    await tester.pumpAndSettle();
    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Compra suspeita'), findsNothing);

    // Todos shows both again.
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Compra suspeita'), findsOneWidget);

    // Internal transfers are dropped entirely on the narrow/mobile list —
    // design.md's Table conventions say "hidden on mobile" (unlike web,
    // which shows them muted).
    expect(find.text('Transferência interna'), findsNothing);
  });

  Future<void> setViewportWidth(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Extrato shows the six-column table with a muted Interna row when wide', (
    tester,
  ) async {
    // Comfortably above kWideBreakpoint, not right at it — see the §6a
    // Web layout phase's nested-breakpoint note (AppGridPage's own page
    // padding narrows the content LayoutBuilder actually sees).
    await setViewportWidth(tester, kWideBreakpoint + 200);

    final backendService = _FakeBackendService();
    final authRepository = AuthRepository(
      authService: _FakeAuthService(),
      backendService: backendService,
      storage: _FakeStorage(),
    );
    await authRepository.login('owner@example.com', 'hunter22');
    final dashboardRepository = DashboardRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    final financeRepository = ExtendedFinanceRepository(
      authRepository: authRepository,
      backendService: backendService,
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
      HouseholdMember(
        id: 'member-b',
        appUserId: 'au-b',
        email: 'b@example.com',
        role: 'member',
        createdAt: DateTime(2026, 1, 2),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdScope(
          controller: scope,
          child: AccountsView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            householdId: 'household-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Six-column header, per design.md's exact column order.
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Descrição'), findsOneWidget);
    expect(find.text('Membro'), findsOneWidget);
    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('Categoria'), findsOneWidget);
    expect(find.text('Valor'), findsOneWidget);

    // Member column resolves dot + email via the account's owner, same as
    // the mobile grouping.
    expect(find.text('a@example.com'), findsWidgets);

    // Internal transfer stays visible on web, tagged and muted.
    expect(find.text('Transferência interna'), findsOneWidget);
    expect(find.text('Interna'), findsOneWidget);

    // A split transaction shows a "Dividida" tag instead of its (now
    // stale) single category.
    expect(find.text('Dividida'), findsOneWidget);
  });

  testWidgets('tapping a row on wide opens the detail panel while the list stays visible', (
    tester,
  ) async {
    await setViewportWidth(tester, kWideBreakpoint + 200);

    final backendService = _FakeBackendService();
    final authRepository = AuthRepository(
      authService: _FakeAuthService(),
      backendService: backendService,
      storage: _FakeStorage(),
    );
    await authRepository.login('owner@example.com', 'hunter22');
    final dashboardRepository = DashboardRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    final financeRepository = ExtendedFinanceRepository(
      authRepository: authRepository,
      backendService: backendService,
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
          child: AccountsView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            householdId: 'household-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salário'));
    await tester.pumpAndSettle();

    // The list (six-column header) is still visible behind the panel —
    // design.md's "list stays visible behind it" requirement. "Categoria"
    // now legitimately appears twice: the table's own column header, plus
    // the panel's category section title.
    expect(find.text('Descrição'), findsOneWidget);
    expect(find.text('Categoria'), findsNWidgets(2));
    // Panel content, including a close affordance.
    expect(find.text('Alterar categoria'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('tapping a row on narrow opens the bottom sheet', (tester) async {
    final backendService = _FakeBackendService();
    final authRepository = AuthRepository(
      authService: _FakeAuthService(),
      backendService: backendService,
      storage: _FakeStorage(),
    );
    await authRepository.login('owner@example.com', 'hunter22');
    final dashboardRepository = DashboardRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    final financeRepository = ExtendedFinanceRepository(
      authRepository: authRepository,
      backendService: backendService,
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
          child: AccountsView(
            dashboardRepository: dashboardRepository,
            financeRepository: financeRepository,
            householdId: 'household-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salário'));
    await tester.pumpAndSettle();

    expect(find.text('Alterar categoria'), findsOneWidget);
  });
}
