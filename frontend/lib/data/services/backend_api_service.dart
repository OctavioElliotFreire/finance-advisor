import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/anomaly.dart';
import '../models/dashboard.dart';
import '../models/extended_finance.dart';
import '../models/household.dart';
import '../models/me.dart';
import '../models/pluggy_connection.dart';
import 'api_exception.dart';

/// All authenticated calls to the FastAPI backend. Every request carries the
/// current Supabase access token — the backend re-validates it independently
/// (see backend/app/auth/supabase.py) rather than trusting the client.
class BackendApiService {
  BackendApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _url(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Map<String, String> _authHeaders(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    if (response.statusCode >= 300) {
      String message = 'Request failed';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = (body['detail'] ?? message).toString();
      } catch (_) {
        // response body wasn't JSON — fall back to the generic message.
      }
      throw ApiException(message, statusCode: response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Me> getMe(String accessToken) async {
    final response = await _client.get(
      _url('/v1/me'),
      headers: _authHeaders(accessToken),
    );
    return Me.fromJson(_decodeOrThrow(response));
  }

  Future<List<Household>> listHouseholds(String accessToken) async {
    final response = await _client.get(
      _url('/v1/households'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(Household.fromJson)
        .toList();
  }

  Future<Household> createHousehold(String accessToken, String name) async {
    final response = await _client.post(
      _url('/v1/households'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({'name': name}),
    );
    final body = _decodeOrThrow(response);
    // The create endpoint doesn't echo role — the caller is always made
    // owner (backend/app/api/households.py::create_household).
    return Household(
      id: body['id'] as String,
      name: body['name'] as String,
      createdAt: DateTime.parse(body['created_at'] as String),
      role: 'owner',
    );
  }

  Future<Household> getHousehold(String accessToken, String householdId) async {
    final response = await _client.get(
      _url('/v1/households/$householdId'),
      headers: _authHeaders(accessToken),
    );
    return Household.fromJson(_decodeOrThrow(response));
  }

  Future<String> createConnectToken(String accessToken, String householdId) async {
    final response = await _client.post(
      _url('/v1/households/$householdId/connections/token'),
      headers: _authHeaders(accessToken),
    );
    return _decodeOrThrow(response)['connect_token'] as String;
  }

  Future<List<PluggyConnection>> listConnections(
    String accessToken,
    String householdId,
  ) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/connections'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map(PluggyConnection.fromJson)
        .toList();
  }

  Future<PluggyConnection> createConnection(
    String accessToken,
    String householdId,
    String pluggyItemId,
  ) async {
    final response = await _client.post(
      _url('/v1/households/$householdId/connections'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({'pluggy_item_id': pluggyItemId}),
    );
    return PluggyConnection.fromJson(_decodeOrThrow(response));
  }

  Future<Dashboard> getDashboard(String accessToken, String householdId) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/dashboard'),
      headers: _authHeaders(accessToken),
    );
    return Dashboard.fromJson(_decodeOrThrow(response));
  }

  Future<List<CreditCardBillSummary>> getCreditCardBills(
    String accessToken,
    String householdId,
  ) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/credit-card-bills'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(CreditCardBillSummary.fromJson).toList();
  }

  Future<List<InvestmentSummary>> getInvestments(
    String accessToken,
    String householdId,
  ) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/investments'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(InvestmentSummary.fromJson).toList();
  }

  Future<List<LoanSummary>> getLoans(String accessToken, String householdId) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/loans'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(LoanSummary.fromJson).toList();
  }

  Future<List<BalancePoint>> getBalanceHistory(
    String accessToken,
    String householdId, {
    int days = 90,
  }) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/balance-history?days=$days'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(BalancePoint.fromJson).toList();
  }

  Future<List<CategoryBreakdownItem>> getCategoryBreakdown(
    String accessToken,
    String householdId, {
    int months = 1,
  }) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/categories?months=$months'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(CategoryBreakdownItem.fromJson).toList();
  }

  Future<List<AnomalySummary>> getAnomalies(
    String accessToken,
    String householdId, {
    String? statusFilter,
  }) async {
    final path = statusFilter == null
        ? '/v1/households/$householdId/anomalies'
        : '/v1/households/$householdId/anomalies?status_filter=$statusFilter';
    final response = await _client.get(_url(path), headers: _authHeaders(accessToken));
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(AnomalySummary.fromJson).toList();
  }

  Future<AnomalySummary> explainAnomaly(
    String accessToken,
    String householdId,
    String anomalyId,
  ) async {
    final response = await _client.post(
      _url('/v1/households/$householdId/anomalies/$anomalyId/explain'),
      headers: _authHeaders(accessToken),
    );
    return AnomalySummary.fromJson(_decodeOrThrow(response));
  }

  Future<AnomalySummary> updateAnomalyStatus(
    String accessToken,
    String householdId,
    String anomalyId,
    String status,
  ) async {
    final response = await _client.patch(
      _url('/v1/households/$householdId/anomalies/$anomalyId'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({'status': status}),
    );
    return AnomalySummary.fromJson(_decodeOrThrow(response));
  }
}
