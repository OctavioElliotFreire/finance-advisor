import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/data/models/extended_finance.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/repositories/extended_finance_repository.dart';
import 'package:frontend/data/services/backend_api_service.dart';

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<BackendApiService>(),
])
import 'extended_finance_repository_test.mocks.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockBackendApiService backendService;
  late ExtendedFinanceRepository repository;

  setUp(() {
    authRepository = MockAuthRepository();
    backendService = MockBackendApiService();
    repository = ExtendedFinanceRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    when(authRepository.getValidAccessToken()).thenAnswer((_) async => 'token-1');
  });

  test('getCreditCardBills forwards the token and household id', () async {
    const bill = CreditCardBillSummary(
      id: 'bill-1',
      accountId: 'acc-1',
      dueDate: null,
      closingDate: null,
      totalAmount: 300.0,
      minimumPayment: 60.0,
      currencyCode: 'BRL',
    );
    when(backendService.getCreditCardBills('token-1', 'household-1'))
        .thenAnswer((_) async => [bill]);

    final result = await repository.getCreditCardBills('household-1');

    expect(result.single.totalAmount, 300.0);
  });

  test('getInvestments forwards the token and household id', () async {
    const investment = InvestmentSummary(
      id: 'inv-1',
      name: 'CDB',
      type: 'FIXED_INCOME',
      subtype: null,
      balance: 1000.0,
      value: 1000.0,
      quantity: 1.0,
      currencyCode: 'BRL',
      investmentDate: null,
    );
    when(backendService.getInvestments('token-1', 'household-1'))
        .thenAnswer((_) async => [investment]);

    final result = await repository.getInvestments('household-1');

    expect(result.single.name, 'CDB');
  });

  test('getLoans forwards the token and household id', () async {
    const loan = LoanSummary(
      id: 'loan-1',
      type: 'PERSONAL',
      status: 'ACTIVE',
      contractAmount: 5000.0,
      outstandingBalance: 4000.0,
      installmentAmount: 500.0,
      installmentsTotal: 10,
      installmentsPaid: 2,
      dueDate: null,
      interestRate: 1.5,
      currencyCode: 'BRL',
    );
    when(backendService.getLoans('token-1', 'household-1')).thenAnswer((_) async => [loan]);

    final result = await repository.getLoans('household-1');

    expect(result.single.outstandingBalance, 4000.0);
  });

  test('getBalanceHistory forwards the token, household id and days', () async {
    final point = BalancePoint(snapshotDate: DateTime(2026, 7, 27), totalBalance: 100.0);
    when(backendService.getBalanceHistory('token-1', 'household-1', days: 30))
        .thenAnswer((_) async => [point]);

    final result = await repository.getBalanceHistory('household-1', days: 30);

    expect(result.single.totalBalance, 100.0);
  });

  test('getCategoryBreakdown forwards the token, household id and months', () async {
    const item = CategoryBreakdownItem(category: 'Food', total: 150.0);
    when(backendService.getCategoryBreakdown('token-1', 'household-1', months: 2))
        .thenAnswer((_) async => [item]);

    final result = await repository.getCategoryBreakdown('household-1', months: 2);

    expect(result.single.category, 'Food');
  });
}
