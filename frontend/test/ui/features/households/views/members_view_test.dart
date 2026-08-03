import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/household_member.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/household_repository.dart';
import 'package:frontend/data/services/api_exception.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';
import 'package:frontend/ui/features/households/views/members_view.dart';

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
  _FakeBackendService({
    this.initialMembers = const [],
    this.inviteError,
  });

  final List<HouseholdMember> initialMembers;
  final ApiException? inviteError;

  @override
  Future<Me> getMe(String accessToken) async {
    return Me(
      id: 'user-1',
      email: 'owner@example.com',
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<HouseholdMember>> listMembers(
    String accessToken,
    String householdId,
  ) async {
    return initialMembers;
  }

  @override
  Future<HouseholdMember> inviteMember(
    String accessToken,
    String householdId,
    String email,
    String role,
  ) async {
    if (inviteError != null) throw inviteError!;
    return HouseholdMember(
      id: 'member-new',
      appUserId: 'appuser-new',
      email: email,
      role: role,
      createdAt: DateTime.now().toUtc(),
    );
  }
}

Future<HouseholdRepository> _buildRepository(
  _FakeBackendService backendService,
) async {
  final authRepository = AuthRepository(
    authService: _FakeAuthService(),
    backendService: backendService,
    storage: _FakeStorage(),
  );
  await authRepository.login('owner@example.com', 'hunter22');
  return HouseholdRepository(
    authRepository: authRepository,
    backendService: backendService,
  );
}

void main() {
  testWidgets('shows the household members with their roles', (tester) async {
    final repository = await _buildRepository(
      _FakeBackendService(
        initialMembers: [
          HouseholdMember(
            id: 'member-1',
            appUserId: 'appuser-1',
            email: 'owner@example.com',
            role: 'owner',
            createdAt: DateTime.now().toUtc(),
          ),
          HouseholdMember(
            id: 'member-2',
            appUserId: 'appuser-2',
            email: 'kid@example.com',
            role: 'member',
            createdAt: DateTime.now().toUtc(),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MembersView(
          householdRepository: repository,
          householdId: 'household-1',
          householdName: 'Elliot Family',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('Role: owner'), findsOneWidget);
    expect(find.text('kid@example.com'), findsOneWidget);
    expect(find.text('Role: member'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no members', (
    tester,
  ) async {
    final repository = await _buildRepository(_FakeBackendService());

    await tester.pumpWidget(
      MaterialApp(
        home: MembersView(
          householdRepository: repository,
          householdId: 'household-1',
          householdName: 'Elliot Family',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No members yet.'), findsOneWidget);
  });

  testWidgets('inviting an existing user adds them to the list', (
    tester,
  ) async {
    final repository = await _buildRepository(_FakeBackendService());

    await tester.pumpWidget(
      MaterialApp(
        home: MembersView(
          householdRepository: repository,
          householdId: 'household-1',
          householdName: 'Elliot Family',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'newmember@example.com');
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();

    expect(find.text('newmember@example.com'), findsOneWidget);
    expect(find.text('Role: member'), findsOneWidget);
  });

  testWidgets('shows the backend error when inviting an unknown email', (
    tester,
  ) async {
    final repository = await _buildRepository(
      _FakeBackendService(
        inviteError: ApiException(
          'No account found for that email. Ask them to sign up, then invite again.',
          statusCode: 404,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MembersView(
          householdRepository: repository,
          householdId: 'household-1',
          householdName: 'Elliot Family',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ghost@example.com');
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No account found for that email. Ask them to sign up, then invite again.',
      ),
      findsOneWidget,
    );
  });
}
