import 'package:flutter/foundation.dart';

import '../../../../data/models/household.dart';
import '../../../../data/repositories/household_repository.dart';
import '../../../../data/services/api_exception.dart';

class HouseholdViewModel extends ChangeNotifier {
  HouseholdViewModel({required HouseholdRepository householdRepository})
    : _householdRepository = householdRepository;

  final HouseholdRepository _householdRepository;

  List<Household> _households = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Household> get households => _households;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _households = await _householdRepository.listHouseholds();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Não foi possível carregar as famílias.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create(String name) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final household = await _householdRepository.createHousehold(name);
      _households = [..._households, household];
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Não foi possível criar a família.';
      notifyListeners();
      return false;
    }
  }
}
