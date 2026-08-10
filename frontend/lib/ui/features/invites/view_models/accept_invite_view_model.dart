import 'package:flutter/foundation.dart';

import '../../../../data/models/household_invite.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/household_repository.dart';
import '../../../../data/services/api_exception.dart';

class AcceptInviteViewModel extends ChangeNotifier {
  AcceptInviteViewModel({
    required AuthRepository authRepository,
    required HouseholdRepository householdRepository,
    required String inviteId,
  }) : _authRepository = authRepository,
       _householdRepository = householdRepository,
       _inviteId = inviteId;

  final AuthRepository _authRepository;
  final HouseholdRepository _householdRepository;
  final String _inviteId;

  InvitePreview? _preview;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  AcceptInviteResult? _result;

  InvitePreview? get preview => _preview;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  AcceptInviteResult? get result => _result;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _preview = await _householdRepository.getInvitePreview(_inviteId);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Não foi possível carregar este convite.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submit(String password) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.updatePassword(password);
      _result = await _householdRepository.acceptInvite(_inviteId);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Não foi possível aceitar este convite.';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
