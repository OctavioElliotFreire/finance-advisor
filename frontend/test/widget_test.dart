import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/app.dart';
import 'package:frontend/app/router.dart';
import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/repositories/anomaly_repository.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/connection_repository.dart';
import 'package:frontend/data/repositories/dashboard_repository.dart';
import 'package:frontend/data/repositories/extended_finance_repository.dart';
import 'package:frontend/data/repositories/household_repository.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';

class _NoSessionStorage extends SecureTokenStorage {
  @override
  Future<AuthSession?> readSession() async => null;

  @override
  Future<void> saveSession(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}

class _FakeAuthService extends SupabaseAuthService {
  @override
  Future<AuthSession> signIn(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> signUp(String email, String password) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('shows the splash screen while the session is restoring', (
    tester,
  ) async {
    final authRepository = AuthRepository(
      authService: _FakeAuthService(),
      storage: _NoSessionStorage(),
    );
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
    final router = buildRouter(
      authRepository: authRepository,
      householdRepository: householdRepository,
      connectionRepository: connectionRepository,
      dashboardRepository: dashboardRepository,
      financeRepository: financeRepository,
      anomalyRepository: anomalyRepository,
    );

    await tester.pumpWidget(FamilyFinanceApp(router: router));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
