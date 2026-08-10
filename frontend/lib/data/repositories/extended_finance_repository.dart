import '../models/extended_finance.dart';
import '../services/backend_api_service.dart';
import 'auth_repository.dart';

class ExtendedFinanceRepository {
  ExtendedFinanceRepository({
    required AuthRepository authRepository,
    BackendApiService? backendService,
  }) : _authRepository = authRepository,
       _backendService = backendService ?? BackendApiService();

  final AuthRepository _authRepository;
  final BackendApiService _backendService;

  Future<List<CreditCardBillSummary>> getCreditCardBills(
    String householdId, {
    Set<String>? memberIds,
  }) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getCreditCardBills(
      token,
      householdId,
      memberIds: memberIds?.toList(),
    );
  }

  Future<List<InvestmentSummary>> getInvestments(
    String householdId, {
    Set<String>? memberIds,
  }) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getInvestments(
      token,
      householdId,
      memberIds: memberIds?.toList(),
    );
  }

  Future<List<LoanSummary>> getLoans(
    String householdId, {
    Set<String>? memberIds,
  }) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getLoans(
      token,
      householdId,
      memberIds: memberIds?.toList(),
    );
  }

  Future<List<BalancePoint>> getBalanceHistory(
    String householdId, {
    int days = 90,
    Set<String>? memberIds,
  }) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getBalanceHistory(
      token,
      householdId,
      days: days,
      memberIds: memberIds?.toList(),
    );
  }

  Future<List<CategoryBreakdownItem>> getCategoryBreakdown(
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
    Set<String>? memberIds,
    bool comparePrevious = false,
  }) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getCategoryBreakdown(
      token,
      householdId,
      startDate: startDate,
      endDate: endDate,
      memberIds: memberIds?.toList(),
      comparePrevious: comparePrevious,
    );
  }
}
