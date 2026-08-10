import 'package:flutter/foundation.dart';

import '../../../../data/models/dashboard.dart';
import '../../../../data/repositories/dashboard_repository.dart';
import '../../../../data/services/api_exception.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required DashboardRepository dashboardRepository,
    required String householdId,
  }) : _dashboardRepository = dashboardRepository,
       _householdId = householdId;

  final DashboardRepository _dashboardRepository;
  final String _householdId;

  Dashboard? _dashboard;
  bool _isLoading = false;
  String? _errorMessage;

  Dashboard? get dashboard => _dashboard;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _dashboard = await _dashboardRepository.getDashboard(_householdId);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Não foi possível carregar o painel.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
