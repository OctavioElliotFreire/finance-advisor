import '../models/anomaly.dart';
import '../models/dashboard.dart';
import '../services/backend_api_service.dart';
import 'auth_repository.dart';

class DashboardRepository {
  DashboardRepository({
    required AuthRepository authRepository,
    BackendApiService? backendService,
  }) : _authRepository = authRepository,
       _backendService = backendService ?? BackendApiService();

  final AuthRepository _authRepository;
  final BackendApiService _backendService;

  Future<Dashboard> getDashboard(
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
    Set<String>? memberIds,
  }) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getDashboard(
      token,
      householdId,
      startDate: startDate,
      endDate: endDate,
      memberIds: memberIds?.toList(),
    );
  }

  Future<List<TransactionSummary>> listTransactions(
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
    Set<String>? memberIds,
    int limit = 50,
    int offset = 0,
  }) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.listTransactions(
      token,
      householdId,
      startDate: startDate,
      endDate: endDate,
      memberIds: memberIds?.toList(),
      limit: limit,
      offset: offset,
    );
  }

  Future<TransactionSummary> updateTransactionCategory(
    String householdId,
    String transactionId,
    String? category,
  ) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.updateTransactionCategory(
      token,
      householdId,
      transactionId,
      category,
    );
  }

  Future<TransactionSummary> updateTransactionSplits(
    String householdId,
    String transactionId,
    List<TransactionSplitItem> splits,
  ) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.updateTransactionSplits(
      token,
      householdId,
      transactionId,
      splits,
    );
  }

  Future<AnomalySummary> flagTransaction(
    String householdId,
    String transactionId,
  ) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.flagTransaction(token, householdId, transactionId);
  }

  Future<AnomalySummary> updateAnomalyStatus(
    String householdId,
    String anomalyId,
    String status,
  ) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.updateAnomalyStatus(
      token,
      householdId,
      anomalyId,
      status,
    );
  }
}
