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

  Future<List<CreditCardBillSummary>> getCreditCardBills(String householdId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getCreditCardBills(token, householdId);
  }

  Future<List<InvestmentSummary>> getInvestments(String householdId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getInvestments(token, householdId);
  }

  Future<List<LoanSummary>> getLoans(String householdId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getLoans(token, householdId);
  }

  Future<List<BalancePoint>> getBalanceHistory(String householdId, {int days = 90}) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getBalanceHistory(token, householdId, days: days);
  }

  Future<List<CategoryBreakdownItem>> getCategoryBreakdown(
    String householdId, {
    int months = 1,
  }) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getCategoryBreakdown(token, householdId, months: months);
  }
}
