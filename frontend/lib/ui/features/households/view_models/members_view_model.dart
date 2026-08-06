import 'package:flutter/foundation.dart';

import '../../../../data/models/household_invite.dart';
import '../../../../data/models/household_member.dart';
import '../../../../data/repositories/household_repository.dart';
import '../../../../data/services/api_exception.dart';

class MembersViewModel extends ChangeNotifier {
  MembersViewModel({
    required HouseholdRepository householdRepository,
    required String householdId,
  }) : _householdRepository = householdRepository,
       _householdId = householdId;

  final HouseholdRepository _householdRepository;
  final String _householdId;

  List<HouseholdMember> _members = [];
  List<InviteSummary> _pendingInvites = [];
  bool _isLoading = false;
  bool _isInviting = false;
  String? _errorMessage;

  List<HouseholdMember> get members => _members;
  List<InviteSummary> get pendingInvites => _pendingInvites;
  bool get isLoading => _isLoading;
  bool get isInviting => _isInviting;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _members = await _householdRepository.listMembers(_householdId);
      _pendingInvites = await _householdRepository.listPendingInvites(_householdId);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Could not load members.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the invite outcome ("added" or "invited") on success, null on
  /// failure — the view uses this to show the right confirmation message.
  Future<String?> inviteMember(String email, String role) async {
    _isInviting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _householdRepository.inviteMember(
        _householdId,
        email,
        role,
      );
      if (result.outcome == 'added') {
        _members = [..._members, result.member!];
      } else {
        _pendingInvites = [..._pendingInvites, result.invite!];
      }
      return result.outcome;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Could not invite this member.';
      return null;
    } finally {
      _isInviting = false;
      notifyListeners();
    }
  }
}
