import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/household_invite.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/household_repository.dart';
import 'package:frontend/data/services/api_exception.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';
import 'package:frontend/ui/features/invites/views/accept_invite_view.dart';

class _FakeAuthService extends SupabaseAuthService {
  final List<String> passwordUpdates = [];

  @override
  Future<void> updatePassword(String accessToken, String newPassword) async {
    passwordUpdates.add(newPassword);
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
  _FakeBackendService({required this.preview, this.acceptError});

  final InvitePreview preview;
  final ApiException? acceptError;

  @override
  Future<Me> getMe(String accessToken) async {
    return Me(id: 'user-1', email: 'invitee@example.com', createdAt: DateTime.now().toUtc());
  }

  @override
  Future<InvitePreview> getInvitePreview(String inviteId) async => preview;

  @override
  Future<AcceptInviteResult> acceptInvite(String accessToken, String inviteId) async {
    if (acceptError != null) throw acceptError!;
    return AcceptInviteResult(householdId: 'household-1', householdName: 'Elliot Family');
  }
}

Future<(AuthRepository, HouseholdRepository, _FakeAuthService)> _build(
  _FakeBackendService backendService,
) async {
  final fakeAuthService = _FakeAuthService();
  final authRepository = AuthRepository(
    authService: fakeAuthService,
    backendService: backendService,
    storage: _FakeStorage(),
  );
  await authRepository.applyInviteSession(
    AuthSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      userId: 'user-1',
      email: 'invitee@example.com',
    ),
  );
  final householdRepository = HouseholdRepository(
    authRepository: authRepository,
    backendService: backendService,
  );
  return (authRepository, householdRepository, fakeAuthService);
}

void main() {
  testWidgets('renders the invite preview', (tester) async {
    final (authRepository, householdRepository, _) = await _build(
      _FakeBackendService(
        preview: const InvitePreview(
          householdName: 'Elliot Family',
          email: 'invitee@example.com',
          role: 'member',
          expired: false,
          accepted: false,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AcceptInviteView(
          authRepository: authRepository,
          householdRepository: householdRepository,
          inviteId: 'invite-1',
          onAccepted: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Elliot Family'), findsOneWidget);
    expect(find.text('Set a password to finish creating your account.'), findsOneWidget);
  });

  testWidgets('shows an expired message and no form', (tester) async {
    final (authRepository, householdRepository, _) = await _build(
      _FakeBackendService(
        preview: const InvitePreview(
          householdName: 'Elliot Family',
          email: 'invitee@example.com',
          role: 'member',
          expired: true,
          accepted: false,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AcceptInviteView(
          authRepository: authRepository,
          householdRepository: householdRepository,
          inviteId: 'invite-1',
          onAccepted: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('expired'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('submitting a matching password sets it and accepts the invite', (
    tester,
  ) async {
    final (authRepository, householdRepository, fakeAuthService) = await _build(
      _FakeBackendService(
        preview: const InvitePreview(
          householdName: 'Elliot Family',
          email: 'invitee@example.com',
          role: 'member',
          expired: false,
          accepted: false,
        ),
      ),
    );
    String? acceptedHouseholdId;
    String? acceptedHouseholdName;

    await tester.pumpWidget(
      MaterialApp(
        home: AcceptInviteView(
          authRepository: authRepository,
          householdRepository: householdRepository,
          inviteId: 'invite-1',
          onAccepted: (id, name) {
            acceptedHouseholdId = id;
            acceptedHouseholdName = name;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('accept_invite_password_field')),
      'newpassword1',
    );
    await tester.enterText(
      find.byKey(const Key('accept_invite_confirm_password_field')),
      'newpassword1',
    );
    await tester.tap(find.text('Join household'));
    await tester.pumpAndSettle();

    expect(fakeAuthService.passwordUpdates, ['newpassword1']);
    expect(acceptedHouseholdId, 'household-1');
    expect(acceptedHouseholdName, 'Elliot Family');
  });

  testWidgets('shows the backend error when accepting fails', (tester) async {
    final (authRepository, householdRepository, _) = await _build(
      _FakeBackendService(
        preview: const InvitePreview(
          householdName: 'Elliot Family',
          email: 'invitee@example.com',
          role: 'member',
          expired: false,
          accepted: false,
        ),
        acceptError: ApiException(
          'This invite has already been accepted.',
          statusCode: 409,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AcceptInviteView(
          authRepository: authRepository,
          householdRepository: householdRepository,
          inviteId: 'invite-1',
          onAccepted: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('accept_invite_password_field')),
      'newpassword1',
    );
    await tester.enterText(
      find.byKey(const Key('accept_invite_confirm_password_field')),
      'newpassword1',
    );
    await tester.tap(find.text('Join household'));
    await tester.pumpAndSettle();

    expect(find.text('This invite has already been accepted.'), findsOneWidget);
  });

  testWidgets('shows a validation error when passwords do not match', (tester) async {
    final (authRepository, householdRepository, _) = await _build(
      _FakeBackendService(
        preview: const InvitePreview(
          householdName: 'Elliot Family',
          email: 'invitee@example.com',
          role: 'member',
          expired: false,
          accepted: false,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AcceptInviteView(
          authRepository: authRepository,
          householdRepository: householdRepository,
          inviteId: 'invite-1',
          onAccepted: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('accept_invite_password_field')),
      'newpassword1',
    );
    await tester.enterText(
      find.byKey(const Key('accept_invite_confirm_password_field')),
      'different',
    );
    await tester.tap(find.text('Join household'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
