import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/data/models/dashboard.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/dashboard_repository.dart';
import 'package:frontend/data/services/backend_api_service.dart';

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<BackendApiService>(),
])
import 'dashboard_repository_test.mocks.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockBackendApiService backendService;
  late DashboardRepository repository;

  final dashboard = Dashboard(
    householdName: 'Some Household',
    accounts: const [
      AccountSummary(
        id: 'acc-1',
        name: 'Checking',
        type: 'BANK',
        subtype: null,
        balance: 100.0,
        currencyCode: 'BRL',
      ),
    ],
    totalBalance: 100.0,
    recentTransactions: const [],
    monthlyCashFlow: const [],
    syncStatus: const SyncStatus(status: 'completed', updatedAt: null),
  );

  setUp(() {
    authRepository = MockAuthRepository();
    backendService = MockBackendApiService();
    repository = DashboardRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    when(authRepository.getValidAccessToken()).thenAnswer((_) async => 'token-1');
  });

  test('getDashboard forwards the current access token and household id', () async {
    when(backendService.getDashboard('token-1', 'household-1'))
        .thenAnswer((_) async => dashboard);

    final result = await repository.getDashboard('household-1');

    expect(result.totalBalance, 100.0);
    expect(result.accounts.single.name, 'Checking');
  });
}
