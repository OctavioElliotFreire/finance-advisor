import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/connection_access.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/household_repository.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';
import 'package:frontend/ui/features/households/views/member_access_view.dart';

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
  _FakeBackendService({required this.entries});

  final List<ConnectionAccessEntry> entries;
  List<String>? savedConnectionIds;

  @override
  Future<Me> getMe(String accessToken) async {
    return Me(id: 'user-1', email: 'owner@example.com', createdAt: DateTime.now().toUtc());
  }

  @override
  Future<List<ConnectionAccessEntry>> getMemberAccess(
    String accessToken,
    String householdId,
    String memberId,
  ) async {
    return entries;
  }

  @override
  Future<List<ConnectionAccessEntry>> updateMemberAccess(
    String accessToken,
    String householdId,
    String memberId,
    List<String> connectionIds,
  ) async {
    savedConnectionIds = connectionIds;
    return [
      for (final entry in entries) entry.copyWith(granted: connectionIds.contains(entry.connectionId)),
    ];
  }
}

Future<HouseholdRepository> _buildRepository(_FakeBackendService backendService) async {
  final authRepository = AuthRepository(
    authService: _FakeAuthService(),
    backendService: backendService,
    storage: _FakeStorage(),
  );
  await authRepository.login('owner@example.com', 'hunter22');
  return HouseholdRepository(authRepository: authRepository, backendService: backendService);
}

void main() {
  testWidgets('renders each connection with its current grant state', (tester) async {
    final repository = await _buildRepository(
      _FakeBackendService(
        entries: [
          const ConnectionAccessEntry(
            connectionId: 'conn-1',
            pluggyItemId: 'item-1',
            status: 'UPDATED',
            granted: true,
          ),
          const ConnectionAccessEntry(
            connectionId: 'conn-2',
            pluggyItemId: 'item-2',
            status: 'UPDATED',
            granted: false,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MemberAccessView(
          householdRepository: repository,
          householdId: 'household-1',
          memberId: 'member-1',
          memberEmail: 'kid@example.com',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkboxes = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(checkboxes.length, 2);
    expect(checkboxes[0].value, true);
    expect(checkboxes[1].value, false);
  });

  testWidgets('toggling and saving persists the new selection', (tester) async {
    final backendService = _FakeBackendService(
      entries: [
        const ConnectionAccessEntry(
          connectionId: 'conn-1',
          pluggyItemId: 'item-1',
          status: 'UPDATED',
          granted: false,
        ),
      ],
    );
    final repository = await _buildRepository(backendService);

    await tester.pumpWidget(
      MaterialApp(
        home: MemberAccessView(
          householdRepository: repository,
          householdId: 'household-1',
          memberId: 'member-1',
          memberEmail: 'kid@example.com',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(backendService.savedConnectionIds, ['conn-1']);
    expect(find.text('Access updated.'), findsOneWidget);
  });

  testWidgets('shows an empty state when the household has no connections', (
    tester,
  ) async {
    final repository = await _buildRepository(_FakeBackendService(entries: []));

    await tester.pumpWidget(
      MaterialApp(
        home: MemberAccessView(
          householdRepository: repository,
          householdId: 'household-1',
          memberId: 'member-1',
          memberEmail: 'kid@example.com',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No connections in this household yet'), findsOneWidget);
  });
}
