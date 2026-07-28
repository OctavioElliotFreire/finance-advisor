import '../models/pluggy_connection.dart';
import '../services/backend_api_service.dart';
import 'auth_repository.dart';

class ConnectionRepository {
  ConnectionRepository({
    required AuthRepository authRepository,
    BackendApiService? backendService,
  }) : _authRepository = authRepository,
       _backendService = backendService ?? BackendApiService();

  final AuthRepository _authRepository;
  final BackendApiService _backendService;

  Future<String> createConnectToken(String householdId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.createConnectToken(token, householdId);
  }

  Future<List<PluggyConnection>> listConnections(String householdId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.listConnections(token, householdId);
  }

  Future<PluggyConnection> createConnection(
    String householdId,
    String pluggyItemId,
  ) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.createConnection(token, householdId, pluggyItemId);
  }
}
