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

  Future<Dashboard> getDashboard(String householdId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getDashboard(token, householdId);
  }
}
