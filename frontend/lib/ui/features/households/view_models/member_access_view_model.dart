import 'package:flutter/foundation.dart';

import '../../../../data/models/connection_access.dart';
import '../../../../data/repositories/household_repository.dart';
import '../../../../data/services/api_exception.dart';

class MemberAccessViewModel extends ChangeNotifier {
  MemberAccessViewModel({
    required HouseholdRepository householdRepository,
    required String householdId,
    required String memberId,
  }) : _householdRepository = householdRepository,
       _householdId = householdId,
       _memberId = memberId;

  final HouseholdRepository _householdRepository;
  final String _householdId;
  final String _memberId;

  List<ConnectionAccessEntry> _entries = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<ConnectionAccessEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _entries = await _householdRepository.getMemberAccess(
        _householdId,
        _memberId,
      );
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Não foi possível carregar o acesso deste membro.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggle(String connectionId, bool granted) {
    _entries = [
      for (final entry in _entries)
        if (entry.connectionId == connectionId)
          entry.copyWith(granted: granted)
        else
          entry,
    ];
    notifyListeners();
  }

  Future<bool> save() async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final grantedIds = _entries
          .where((e) => e.granted)
          .map((e) => e.connectionId)
          .toList();
      _entries = await _householdRepository.updateMemberAccess(
        _householdId,
        _memberId,
        grantedIds,
      );
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Não foi possível salvar o acesso deste membro.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
