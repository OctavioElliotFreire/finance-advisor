import 'package:flutter/foundation.dart';

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
  bool _isLoading = false;
  bool _isInviting = false;
  String? _errorMessage;

  List<HouseholdMember> get members => _members;
  bool get isLoading => _isLoading;
  bool get isInviting => _isInviting;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _members = await _householdRepository.listMembers(_householdId);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Could not load members.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> inviteMember(String email, String role) async {
    _isInviting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final member = await _householdRepository.inviteMember(
        _householdId,
        email,
        role,
      );
      _members = [..._members, member];
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Could not invite this member.';
      return false;
    } finally {
      _isInviting = false;
      notifyListeners();
    }
  }
}
