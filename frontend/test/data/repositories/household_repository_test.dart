import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/data/models/connection_access.dart';
import 'package:frontend/data/models/household.dart';
import 'package:frontend/data/models/household_invite.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/household_repository.dart';
import 'package:frontend/data/services/backend_api_service.dart';

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<BackendApiService>(),
])
import 'household_repository_test.mocks.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockBackendApiService backendService;
  late HouseholdRepository repository;

  final household = Household(
    id: 'household-1',
    name: 'Elliot Family',
    createdAt: DateTime.utc(2026),
    role: 'owner',
  );

  setUp(() {
    authRepository = MockAuthRepository();
    backendService = MockBackendApiService();
    repository = HouseholdRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    when(authRepository.getValidAccessToken()).thenAnswer((_) async => 'token-1');
  });

  test('listHouseholds uses the current access token', () async {
    when(backendService.listHouseholds('token-1'))
        .thenAnswer((_) async => [household]);

    final result = await repository.listHouseholds();

    expect(result, [household]);
  });

  test('createHousehold forwards the name and access token', () async {
    when(backendService.createHousehold('token-1', 'Elliot Family'))
        .thenAnswer((_) async => household);

    final result = await repository.createHousehold('Elliot Family');

    expect(result.name, 'Elliot Family');
    expect(result.role, 'owner');
  });

  test('getHousehold uses the current access token', () async {
    when(backendService.getHousehold('token-1', 'household-1'))
        .thenAnswer((_) async => household);

    final result = await repository.getHousehold('household-1');

    expect(result.id, 'household-1');
  });

  test('inviteMember forwards email, role and access token', () async {
    final result = InviteResult(
      outcome: 'invited',
      invite: InviteSummary(
        id: 'invite-1',
        email: 'new@example.com',
        role: 'member',
        expiresAt: DateTime.utc(2026, 8, 11),
        acceptedAt: null,
        createdAt: DateTime.utc(2026, 8, 4),
      ),
    );
    when(backendService.inviteMember('token-1', 'household-1', 'new@example.com', 'member'))
        .thenAnswer((_) async => result);

    final response = await repository.inviteMember(
      'household-1',
      'new@example.com',
      'member',
    );

    expect(response.outcome, 'invited');
    expect(response.invite!.email, 'new@example.com');
  });

  test('listPendingInvites uses the current access token', () async {
    final invite = InviteSummary(
      id: 'invite-1',
      email: 'pending@example.com',
      role: 'viewer',
      expiresAt: DateTime.utc(2026, 8, 11),
      acceptedAt: null,
      createdAt: DateTime.utc(2026, 8, 4),
    );
    when(backendService.listPendingInvites('token-1', 'household-1'))
        .thenAnswer((_) async => [invite]);

    final result = await repository.listPendingInvites('household-1');

    expect(result.single.email, 'pending@example.com');
  });

  test('getInvitePreview does not require an access token', () async {
    final preview = InvitePreview(
      householdName: 'Elliot Family',
      email: 'invitee@example.com',
      role: 'member',
      expired: false,
      accepted: false,
    );
    when(backendService.getInvitePreview('invite-1')).thenAnswer((_) async => preview);

    final result = await repository.getInvitePreview('invite-1');

    expect(result.householdName, 'Elliot Family');
    verifyNever(authRepository.getValidAccessToken());
  });

  test('acceptInvite forwards the invite id and access token', () async {
    final result = AcceptInviteResult(householdId: 'household-1', householdName: 'Elliot Family');
    when(backendService.acceptInvite('token-1', 'invite-1')).thenAnswer((_) async => result);

    final response = await repository.acceptInvite('invite-1');

    expect(response.householdId, 'household-1');
  });

  test('getMemberAccess forwards household id, member id and access token', () async {
    final entry = ConnectionAccessEntry(
      connectionId: 'conn-1',
      pluggyItemId: 'item-1',
      status: 'UPDATED',
      granted: true,
    );
    when(backendService.getMemberAccess('token-1', 'household-1', 'member-1'))
        .thenAnswer((_) async => [entry]);

    final result = await repository.getMemberAccess('household-1', 'member-1');

    expect(result.single.connectionId, 'conn-1');
    expect(result.single.granted, true);
  });

  test('updateMemberAccess forwards the selected connection ids', () async {
    final entry = ConnectionAccessEntry(
      connectionId: 'conn-1',
      pluggyItemId: 'item-1',
      status: 'UPDATED',
      granted: true,
    );
    when(backendService.updateMemberAccess('token-1', 'household-1', 'member-1', ['conn-1']))
        .thenAnswer((_) async => [entry]);

    final result = await repository.updateMemberAccess('household-1', 'member-1', ['conn-1']);

    expect(result.single.granted, true);
  });
}
