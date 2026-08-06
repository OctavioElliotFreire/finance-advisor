import '../models/connection_access.dart';
import '../models/household.dart';
import '../models/household_invite.dart';
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

  Future<InviteResult> inviteMember(
    String householdId,
    String email,
    String role,
  ) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.inviteMember(token, householdId, email, role);
  }

  Future<List<InviteSummary>> listPendingInvites(String householdId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.listPendingInvites(token, householdId);
  }

  Future<InvitePreview> getInvitePreview(String inviteId) async {
    return _backendService.getInvitePreview(inviteId);
  }

  Future<AcceptInviteResult> acceptInvite(String inviteId) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.acceptInvite(token, inviteId);
  }

  Future<List<ConnectionAccessEntry>> getMemberAccess(
    String householdId,
    String memberId,
  ) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.getMemberAccess(token, householdId, memberId);
  }

  Future<List<ConnectionAccessEntry>> updateMemberAccess(
    String householdId,
    String memberId,
    List<String> connectionIds,
  ) async {
    final token = await _authRepository.getValidAccessToken();
    return _backendService.updateMemberAccess(token, householdId, memberId, connectionIds);
  }
}
