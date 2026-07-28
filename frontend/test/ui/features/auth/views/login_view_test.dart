import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';
import 'package:frontend/ui/features/auth/views/login_view.dart';

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

class _FakeBackendService extends BackendApiService {
  @override
  Future<Me> getMe(String accessToken) async {
    return Me(
      id: 'user-1',
      email: 'family@example.com',
      createdAt: DateTime.now().toUtc(),
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

AuthRepository _buildFakeAuthRepository() {
  return AuthRepository(
    authService: _FakeAuthService(),
    backendService: _FakeBackendService(),
    storage: _FakeStorage(),
  );
}

void main() {
  testWidgets('shows validation errors when submitted empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginView(
          authRepository: _buildFakeAuthRepository(),
          onLoggedIn: () {},
          onNavigateToRegister: () {},
        ),
      ),
    );

    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('calls onLoggedIn after a successful login', (tester) async {
    var loggedIn = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginView(
          authRepository: _buildFakeAuthRepository(),
          onLoggedIn: () => loggedIn = true,
          onNavigateToRegister: () {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'family@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'hunter22',
    );
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(loggedIn, isTrue);
  });
}
