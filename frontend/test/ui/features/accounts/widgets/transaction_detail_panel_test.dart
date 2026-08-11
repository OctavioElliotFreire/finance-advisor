import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/anomaly.dart';
import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/dashboard.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/dashboard_repository.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';
import 'package:frontend/ui/features/accounts/widgets/transaction_detail_panel.dart';

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
  String? lastCategory;
  List<TransactionSplitItem>? lastSplits;
  bool flagCalled = false;
  String? lastAnomalyStatus;

  @override
  Future<Me> getMe(String accessToken) async {
    return Me(id: 'user-1', email: 'owner@example.com', createdAt: DateTime.now().toUtc());
  }

  @override
  Future<TransactionSummary> updateTransactionCategory(
    String accessToken,
    String householdId,
    String transactionId,
    String? category,
  ) async {
    lastCategory = category;
    return _baseTransaction().copyWith(category: category);
  }

  @override
  Future<TransactionSummary> updateTransactionSplits(
    String accessToken,
    String householdId,
    String transactionId,
    List<TransactionSplitItem> splits,
  ) async {
    lastSplits = splits;
    return _baseTransaction().copyWith(splits: splits);
  }

  @override
  Future<AnomalySummary> flagTransaction(
    String accessToken,
    String householdId,
    String transactionId,
  ) async {
    flagCalled = true;
    return AnomalySummary(
      id: 'flag-1',
      transactionId: transactionId,
      householdMemberId: null,
      rule: 'manual',
      severity: 'low',
      score: null,
      summary: 'Sinalizado manualmente',
      status: 'open',
      explanation: null,
      explainedAt: null,
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<AnomalySummary> updateAnomalyStatus(
    String accessToken,
    String householdId,
    String anomalyId,
    String status,
  ) async {
    lastAnomalyStatus = status;
    return AnomalySummary(
      id: anomalyId,
      transactionId: 'txn-1',
      householdMemberId: null,
      rule: 'manual',
      severity: 'low',
      score: null,
      summary: 'Sinalizado manualmente',
      status: status,
      explanation: null,
      explainedAt: null,
      createdAt: DateTime.now().toUtc(),
    );
  }
}

TransactionSummary _baseTransaction({String? flagId, List<TransactionSplitItem> splits = const []}) {
  return TransactionSummary(
    id: 'txn-1',
    accountId: 'account-1',
    accountName: 'Conta Corrente',
    description: 'Supermercado',
    amount: -400.0,
    currencyCode: 'BRL',
    transactionDate: DateTime(2026, 7, 15),
    category: 'Compras',
    flagId: flagId,
    splits: splits,
  );
}

Future<DashboardRepository> _buildRepository(_FakeBackendService backendService) async {
  final authRepository = AuthRepository(
    authService: _FakeAuthService(),
    backendService: backendService,
    storage: _FakeStorage(),
  );
  await authRepository.login('owner@example.com', 'hunter22');
  return DashboardRepository(authRepository: authRepository, backendService: backendService);
}

void main() {
  testWidgets('recategorize picker updates category and notifies caller', (tester) async {
    final backendService = _FakeBackendService();
    final dashboardRepository = await _buildRepository(backendService);
    TransactionSummary? updated;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionDetailPanel(
            transaction: _baseTransaction(),
            accountName: 'Conta Corrente',
            memberColor: Colors.blue,
            memberLabel: 'a@example.com',
            knownCategories: const ['Compras', 'Mercado'],
            dashboardRepository: dashboardRepository,
            householdId: 'household-1',
            onUpdated: (t) => updated = t,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alterar categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Mercado'));
    await tester.pumpAndSettle();

    expect(backendService.lastCategory, 'Mercado');
    expect(updated?.category, 'Mercado');
  });

  testWidgets('split editor blocks Save until the remainder is zero', (tester) async {
    final backendService = _FakeBackendService();
    final dashboardRepository = await _buildRepository(backendService);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionDetailPanel(
            transaction: _baseTransaction(),
            accountName: 'Conta Corrente',
            memberColor: Colors.blue,
            memberLabel: 'a@example.com',
            knownCategories: const ['Compras', 'Mercado'],
            dashboardRepository: dashboardRepository,
            householdId: 'household-1',
            onUpdated: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dividir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar divisão'));
    await tester.pumpAndSettle();

    final categoryField = find.widgetWithText(TextField, 'Categoria');
    final amountField = find.widgetWithText(TextField, 'Valor');
    await tester.enterText(categoryField, 'Mercado');
    await tester.enterText(amountField, '300');
    await tester.pump();

    // Remainder is R$100 — Save must stay disabled.
    var saveButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar'));
    expect(saveButton.onPressed, isNull);

    await tester.enterText(amountField, '400');
    await tester.pump();

    saveButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar'));
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(backendService.lastSplits, isNotNull);
    expect(backendService.lastSplits!.single.category, 'Mercado');
    expect(backendService.lastSplits!.single.amount, -400.0);
  });

  testWidgets('flag button toggles between Sinalizar and Remover sinalização', (tester) async {
    final backendService = _FakeBackendService();
    final dashboardRepository = await _buildRepository(backendService);
    TransactionSummary? updated;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionDetailPanel(
            transaction: _baseTransaction(),
            accountName: 'Conta Corrente',
            memberColor: Colors.blue,
            memberLabel: 'a@example.com',
            knownCategories: const ['Compras'],
            dashboardRepository: dashboardRepository,
            householdId: 'household-1',
            onUpdated: (t) => updated = t,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sinalizar'), findsOneWidget);

    await tester.tap(find.text('Sinalizar'));
    await tester.pumpAndSettle();

    expect(backendService.flagCalled, isTrue);
    expect(updated?.flagId, 'flag-1');
    expect(find.text('Remover sinalização'), findsOneWidget);

    await tester.tap(find.text('Remover sinalização'));
    await tester.pumpAndSettle();

    expect(backendService.lastAnomalyStatus, 'dismissed');
    expect(updated?.flagId, isNull);
    expect(find.text('Sinalizar'), findsOneWidget);
  });
}
