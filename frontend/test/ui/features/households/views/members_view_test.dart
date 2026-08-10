import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/household_invite.dart';
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
    this.initialPendingInvites = const [],
    this.inviteError,
    this.inviteAsUnknownEmail = false,
  });

  final List<HouseholdMember> initialMembers;
  final List<InviteSummary> initialPendingInvites;
  final ApiException? inviteError;
  final bool inviteAsUnknownEmail;

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
  Future<List<InviteSummary>> listPendingInvites(
    String accessToken,
    String householdId,
  ) async {
    return initialPendingInvites;
  }

  @override
  Future<InviteResult> inviteMember(
    String accessToken,
    String householdId,
    String email,
    String role,
  ) async {
    if (inviteError != null) throw inviteError!;
    if (inviteAsUnknownEmail) {
      return InviteResult(
        outcome: 'invited',
        invite: InviteSummary(
          id: 'invite-new',
          email: email,
          role: role,
          expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
          acceptedAt: null,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    return InviteResult(
      outcome: 'added',
      member: HouseholdMember(
        id: 'member-new',
        appUserId: 'appuser-new',
        email: email,
        role: role,
        createdAt: DateTime.now().toUtc(),
      ),
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
    expect(find.text('Papel: Responsável'), findsOneWidget);
    expect(find.text('kid@example.com'), findsOneWidget);
    expect(find.text('Papel: Membro'), findsOneWidget);
  });

  testWidgets('shows existing pending invites on load', (tester) async {
    final repository = await _buildRepository(
      _FakeBackendService(
        initialPendingInvites: [
          InviteSummary(
            id: 'invite-1',
            email: 'already-invited@example.com',
            role: 'viewer',
            expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
            acceptedAt: null,
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

    expect(find.text('Convites pendentes'), findsOneWidget);
    expect(find.text('already-invited@example.com'), findsOneWidget);
    expect(find.text('Papel: Visualizador · ainda não aceito'), findsOneWidget);
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

    expect(find.text('Nenhum membro ainda'), findsOneWidget);
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

    await tester.enterText(find.byType(TextFormField), 'newmember@example.com');
    await tester.tap(find.text('Convidar'));
    await tester.pumpAndSettle();

    expect(find.text('newmember@example.com'), findsOneWidget);
    expect(find.text('Papel: Membro'), findsOneWidget);
  });

  testWidgets('shows the backend error when invite fails', (tester) async {
    final repository = await _buildRepository(
      _FakeBackendService(
        inviteError: ApiException(
          'This household has reached its member limit.',
          statusCode: 422,
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

    await tester.enterText(find.byType(TextFormField), 'ghost@example.com');
    await tester.tap(find.text('Convidar'));
    await tester.pumpAndSettle();

    expect(find.text('This household has reached its member limit.'), findsOneWidget);
  });

  testWidgets('inviting an unknown email shows it under pending invites', (
    tester,
  ) async {
    final repository = await _buildRepository(
      _FakeBackendService(inviteAsUnknownEmail: true),
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

    await tester.enterText(find.byType(TextFormField), 'never-signed-up@example.com');
    await tester.tap(find.text('Convidar'));
    await tester.pumpAndSettle();

    expect(find.text('Convites pendentes'), findsOneWidget);
    expect(find.text('never-signed-up@example.com'), findsOneWidget);
    expect(find.text('Papel: Membro · ainda não aceito'), findsOneWidget);
    expect(
      find.text('E-mail de convite enviado para never-signed-up@example.com.'),
      findsOneWidget,
    );
  });

  testWidgets('owner sees a manage-access affordance only on non-owner rows', (
    tester,
  ) async {
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
    String? manageAccessMemberId;

    await tester.pumpWidget(
      MaterialApp(
        home: MembersView(
          householdRepository: repository,
          householdId: 'household-1',
          householdName: 'Elliot Family',
          currentUserEmail: 'owner@example.com',
          onManageAccess: (memberId, memberEmail) => manageAccessMemberId = memberId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Gerenciar acesso'), findsOneWidget);

    await tester.tap(find.byTooltip('Gerenciar acesso'));
    expect(manageAccessMemberId, 'member-2');
  });

  testWidgets('non-owner never sees the manage-access affordance', (tester) async {
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
          currentUserEmail: 'kid@example.com',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Gerenciar acesso'), findsNothing);
  });
}
