import '../models/anomaly.dart';
import '../services/backend_api_service.dart';
import 'auth_repository.dart';

class AnomalyRepository {
  AnomalyRepository({
    required AuthRepository authRepository,
    BackendApiService? backendService,
  }) : _authRepository = authRepository,
       _backendService = backendService ?? BackendApiService();

  final AuthRepository _authRepository;
  final BackendApiService _backendService;

  Future<List<AnomalySummary>> listAnomalies(
    String householdId, {
    String? statusFilter,
  }) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getAnomalies(token, householdId, statusFilter: statusFilter);
  }

  Future<AnomalySummary> explainAnomaly(String householdId, String anomalyId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.explainAnomaly(token, householdId, anomalyId);
  }

  Future<AnomalySummary> updateAnomalyStatus(
    String householdId,
    String anomalyId,
    String status,
  ) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.updateAnomalyStatus(token, householdId, anomalyId, status);
  }
}
