import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/anomaly.dart';
import '../models/assistant_message.dart';
import '../models/connection_access.dart';
import '../models/dashboard.dart';
import '../models/extended_finance.dart';
import '../models/household.dart';
import '../models/household_invite.dart';
import '../models/household_member.dart';
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

  /// Builds a `?a=1&b=2` query string for the Global Scope params
  /// (start/end date + repeated `member_ids=`) shared across the dashboard,
  /// transactions, and extended-finance endpoints. Returns `''` when nothing
  /// is set, so callers can always append it directly to the path.
  String _scopeQueryString({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memberIds,
    Map<String, String>? extra,
  }) {
    final params = <String>[];
    if (startDate != null) params.add('start_date=${_isoDate(startDate)}');
    if (endDate != null) params.add('end_date=${_isoDate(endDate)}');
    for (final id in memberIds ?? const <String>[]) {
      params.add('member_ids=$id');
    }
    extra?.forEach((key, value) => params.add('$key=$value'));
    return params.isEmpty ? '' : '?${params.join('&')}';
  }

  String _isoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

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

  Future<List<HouseholdMember>> listMembers(
    String accessToken,
    String householdId,
  ) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/members'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(HouseholdMember.fromJson).toList();
  }

  Future<InviteResult> inviteMember(
    String accessToken,
    String householdId,
    String email,
    String role,
  ) async {
    final response = await _client.post(
      _url('/v1/households/$householdId/members'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({'email': email, 'role': role}),
    );
    return InviteResult.fromJson(_decodeOrThrow(response));
  }

  Future<List<InviteSummary>> listPendingInvites(
    String accessToken,
    String householdId,
  ) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/invites'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(InviteSummary.fromJson).toList();
  }

  Future<InvitePreview> getInvitePreview(String inviteId) async {
    final response = await _client.get(
      _url('/v1/invites/$inviteId'),
      headers: {'Content-Type': 'application/json'},
    );
    return InvitePreview.fromJson(_decodeOrThrow(response));
  }

  Future<AcceptInviteResult> acceptInvite(String accessToken, String inviteId) async {
    final response = await _client.post(
      _url('/v1/invites/$inviteId/accept'),
      headers: _authHeaders(accessToken),
    );
    return AcceptInviteResult.fromJson(_decodeOrThrow(response));
  }

  Future<List<ConnectionAccessEntry>> getMemberAccess(
    String accessToken,
    String householdId,
    String memberId,
  ) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/members/$memberId/access'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(ConnectionAccessEntry.fromJson).toList();
  }

  Future<List<ConnectionAccessEntry>> updateMemberAccess(
    String accessToken,
    String householdId,
    String memberId,
    List<String> connectionIds,
  ) async {
    final response = await _client.put(
      _url('/v1/households/$householdId/members/$memberId/access'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({'connection_ids': connectionIds}),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(ConnectionAccessEntry.fromJson).toList();
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

  Future<Dashboard> getDashboard(
    String accessToken,
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memberIds,
  }) async {
    final query = _scopeQueryString(
      startDate: startDate,
      endDate: endDate,
      memberIds: memberIds,
    );
    final response = await _client.get(
      _url('/v1/households/$householdId/dashboard$query'),
      headers: _authHeaders(accessToken),
    );
    return Dashboard.fromJson(_decodeOrThrow(response));
  }

  Future<List<TransactionSummary>> listTransactions(
    String accessToken,
    String householdId, {
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memberIds,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = _scopeQueryString(
      startDate: startDate,
      endDate: endDate,
      memberIds: memberIds,
      extra: {'limit': '$limit', 'offset': '$offset'},
    );
    final response = await _client.get(
      _url('/v1/households/$householdId/transactions$query'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(TransactionSummary.fromJson).toList();
  }

  Future<List<CreditCardBillSummary>> getCreditCardBills(
    String accessToken,
    String householdId, {
    List<String>? memberIds,
  }) async {
    final query = _scopeQueryString(memberIds: memberIds);
    final response = await _client.get(
      _url('/v1/households/$householdId/credit-card-bills$query'),
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
    String householdId, {
    List<String>? memberIds,
  }) async {
    final query = _scopeQueryString(memberIds: memberIds);
    final response = await _client.get(
      _url('/v1/households/$householdId/investments$query'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(InvestmentSummary.fromJson).toList();
  }

  Future<List<LoanSummary>> getLoans(
    String accessToken,
    String householdId, {
    List<String>? memberIds,
  }) async {
    final query = _scopeQueryString(memberIds: memberIds);
    final response = await _client.get(
      _url('/v1/households/$householdId/loans$query'),
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
    List<String>? memberIds,
  }) async {
    final query = _scopeQueryString(
      memberIds: memberIds,
      extra: {'days': '$days'},
    );
    final response = await _client.get(
      _url('/v1/households/$householdId/balance-history$query'),
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
    DateTime? startDate,
    DateTime? endDate,
    List<String>? memberIds,
    bool comparePrevious = false,
  }) async {
    final query = _scopeQueryString(
      startDate: startDate,
      endDate: endDate,
      memberIds: memberIds,
      extra: comparePrevious ? {'compare_previous': 'true'} : null,
    );
    final response = await _client.get(
      _url('/v1/households/$householdId/categories$query'),
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

  Future<List<AssistantMessage>> getAssistantMessages(
    String accessToken,
    String householdId,
  ) async {
    final response = await _client.get(
      _url('/v1/households/$householdId/assistant'),
      headers: _authHeaders(accessToken),
    );
    if (response.statusCode >= 300) {
      _decodeOrThrow(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(AssistantMessage.fromJson).toList();
  }

  Future<AssistantMessage> askAssistant(
    String accessToken,
    String householdId,
    String question,
  ) async {
    final response = await _client.post(
      _url('/v1/households/$householdId/assistant/ask'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({'question': question}),
    );
    return AssistantMessage.fromJson(_decodeOrThrow(response));
  }
}
