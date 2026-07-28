import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/data/models/household.dart';
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
}
