import 'package:flutter/foundation.dart';

import '../../../../data/models/pluggy_connection.dart';
import '../../../../data/repositories/connection_repository.dart';
import '../../../../data/services/api_exception.dart';

class ConnectionsViewModel extends ChangeNotifier {
  ConnectionsViewModel({
    required ConnectionRepository connectionRepository,
    required String householdId,
  }) : _connectionRepository = connectionRepository,
       _householdId = householdId;

  final ConnectionRepository _connectionRepository;
  final String _householdId;

  List<PluggyConnection> _connections = [];
  bool _isLoading = false;
  bool _isConnecting = false;
  String? _errorMessage;

  List<PluggyConnection> get connections => _connections;
  bool get isLoading => _isLoading;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _connections = await _connectionRepository.listConnections(_householdId);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Não foi possível carregar as conexões.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> requestConnectToken() async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _connectionRepository.createConnectToken(_householdId);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Não foi possível iniciar o fluxo de conexão.';
      return null;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> registerConnection(String pluggyItemId) async {
    try {
      final connection = await _connectionRepository.createConnection(
        _householdId,
        pluggyItemId,
      );
      _connections = [..._connections, connection];
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Conectado, mas não foi possível salvar a conexão.';
      notifyListeners();
    }
  }
}
