import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/data/models/anomaly.dart';
import 'package:frontend/data/repositories/anomaly_repository.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/services/backend_api_service.dart';

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<BackendApiService>(),
])
import 'anomaly_repository_test.mocks.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockBackendApiService backendService;
  late AnomalyRepository repository;

  final anomaly = AnomalySummary(
    id: 'anomaly-1',
    transactionId: 'txn-1',
    householdMemberId: null,
    rule: 'large_transaction',
    severity: 'high',
    score: 5.2,
    summary: 'R\$ 2000.00 is much larger than usual',
    status: 'open',
    explanation: null,
    explainedAt: null,
    createdAt: DateTime(2026, 7, 27),
  );

  setUp(() {
    authRepository = MockAuthRepository();
    backendService = MockBackendApiService();
    repository = AnomalyRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    when(authRepository.getValidAccessToken()).thenAnswer((_) async => 'token-1');
  });

  test('listAnomalies forwards the token, household id and status filter', () async {
    when(backendService.getAnomalies('token-1', 'household-1', statusFilter: 'open'))
        .thenAnswer((_) async => [anomaly]);

    final result = await repository.listAnomalies('household-1', statusFilter: 'open');

    expect(result.single.rule, 'large_transaction');
  });

  test('explainAnomaly forwards the token, household id and anomaly id', () async {
    final explained = anomaly.copyWith(explanation: 'This is unusual because...');
    when(backendService.explainAnomaly('token-1', 'household-1', 'anomaly-1'))
        .thenAnswer((_) async => explained);

    final result = await repository.explainAnomaly('household-1', 'anomaly-1');

    expect(result.explanation, 'This is unusual because...');
  });

  test('updateAnomalyStatus forwards the token, household id, anomaly id and status', () async {
    final confirmed = anomaly.copyWith(status: 'confirmed');
    when(backendService.updateAnomalyStatus('token-1', 'household-1', 'anomaly-1', 'confirmed'))
        .thenAnswer((_) async => confirmed);

    final result = await repository.updateAnomalyStatus('household-1', 'anomaly-1', 'confirmed');

    expect(result.status, 'confirmed');
  });
}
