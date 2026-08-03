import '../models/household.dart';
import '../models/household_member.dart';
import '../services/backend_api_service.dart';
import 'auth_repository.dart';

class HouseholdRepository {
  HouseholdRepository({
    required AuthRepository authRepository,
    BackendApiService? backendService,
  }) : _authRepository = authRepository,
       _backendService = backendService ?? BackendApiService();

  final AuthRepository _authRepository;
  final BackendApiService _backendService;

  Future<List<Household>> listHouseholds() async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.listHouseholds(token);
  }

  Future<Household> createHousehold(String name) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.createHousehold(token, name);
  }

  Future<Household> getHousehold(String householdId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getHousehold(token, householdId);
  }

  Future<List<HouseholdMember>> listMembers(String householdId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.listMembers(token, householdId);
  }

  Future<HouseholdMember> inviteMember(
    String householdId,
    String email,
    String role,
  ) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.inviteMember(token, householdId, email, role);
  }
}
