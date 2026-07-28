import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/data/models/pluggy_connection.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/connection_repository.dart';
import 'package:frontend/data/services/backend_api_service.dart';

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<BackendApiService>(),
])
import 'connection_repository_test.mocks.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockBackendApiService backendService;
  late ConnectionRepository repository;

  final connection = PluggyConnection(
    id: 'connection-1',
    pluggyItemId: 'item-1',
    status: 'UPDATED',
    createdAt: DateTime.utc(2026),
  );

  setUp(() {
    authRepository = MockAuthRepository();
    backendService = MockBackendApiService();
    repository = ConnectionRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    when(authRepository.getValidAccessToken()).thenAnswer((_) async => 'token-1');
  });

  test('createConnectToken forwards the current access token', () async {
    when(backendService.createConnectToken('token-1', 'household-1'))
        .thenAnswer((_) async => 'connect-token-abc');

    final token = await repository.createConnectToken('household-1');

    expect(token, 'connect-token-abc');
  });

  test('listConnections returns connections for the household', () async {
    when(backendService.listConnections('token-1', 'household-1'))
        .thenAnswer((_) async => [connection]);

    final result = await repository.listConnections('household-1');

    expect(result, [connection]);
  });

  test('createConnection forwards the item id', () async {
    when(backendService.createConnection('token-1', 'household-1', 'item-1'))
        .thenAnswer((_) async => connection);

    final result = await repository.createConnection('household-1', 'item-1');

    expect(result.pluggyItemId, 'item-1');
  });
}
