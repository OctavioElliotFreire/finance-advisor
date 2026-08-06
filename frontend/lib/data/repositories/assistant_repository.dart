import '../models/assistant_message.dart';
import '../services/backend_api_service.dart';
import 'auth_repository.dart';

class AssistantRepository {
  AssistantRepository({
    required AuthRepository authRepository,
    BackendApiService? backendService,
  }) : _authRepository = authRepository,
       _backendService = backendService ?? BackendApiService();

  final AuthRepository _authRepository;
  final BackendApiService _backendService;

  Future<List<AssistantMessage>> getHistory(String householdId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getAssistantMessages(token, householdId);
  }

  Future<AssistantMessage> ask(String householdId, String question) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.askAssistant(token, householdId, question);
  }
}
