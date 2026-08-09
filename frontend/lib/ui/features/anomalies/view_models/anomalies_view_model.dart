import 'package:flutter/foundation.dart';

import '../../../../data/models/anomaly.dart';
import '../../../../data/repositories/anomaly_repository.dart';
import '../../../../data/services/api_exception.dart';

class AnomaliesViewModel extends ChangeNotifier {
  AnomaliesViewModel({
    required AnomalyRepository anomalyRepository,
    required String householdId,
  }) : _anomalyRepository = anomalyRepository,
       _householdId = householdId;

  final AnomalyRepository _anomalyRepository;
  final String _householdId;

  List<AnomalySummary> _anomalies = const [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _statusFilter;
  final Set<String> _explainingIds = {};

  List<AnomalySummary> get anomalies => _anomalies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get statusFilter => _statusFilter;
  bool isExplaining(String anomalyId) => _explainingIds.contains(anomalyId);

  Future<void> load({String? statusFilter}) async {
    _statusFilter = statusFilter;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _anomalies = await _anomalyRepository.listAnomalies(
        _householdId,
        statusFilter: statusFilter,
      );
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Could not load anomalies.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> explain(String anomalyId) async {
    _explainingIds.add(anomalyId);
    notifyListeners();
    try {
      final updated = await _anomalyRepository.explainAnomaly(
        _householdId,
        anomalyId,
      );
      _replace(updated);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Could not explain this anomaly.';
    } finally {
      _explainingIds.remove(anomalyId);
      notifyListeners();
    }
  }

  Future<void> updateStatus(String anomalyId, String status) async {
    try {
      final updated = await _anomalyRepository.updateAnomalyStatus(
        _householdId,
        anomalyId,
        status,
      );
      _replace(updated);
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Could not update this anomaly.';
      notifyListeners();
    }
  }

  void _replace(AnomalySummary updated) {
    _anomalies = [
      for (final anomaly in _anomalies)
        if (anomaly.id == updated.id) updated else anomaly,
    ];
  }
}
