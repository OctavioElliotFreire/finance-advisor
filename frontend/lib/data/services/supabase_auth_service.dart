import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/auth_session.dart';
import 'api_exception.dart';

/// Talks directly to Supabase Auth's REST API. This is the one exception to
/// "Flutter only talks to FastAPI" (see PLAN.md) — auth itself is handled by
/// Supabase directly, and the resulting access token is what gets sent to
/// FastAPI on every other request.
class SupabaseAuthService {
  SupabaseAuthService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Uri _authUrl(String path) => Uri.parse('${AppConfig.supabaseUrl}$path');

  Map<String, String> get _headers => {
    'apikey': AppConfig.supabaseAnonKey,
    'Content-Type': 'application/json',
  };

  Future<AuthSession> signUp(String email, String password) async {
    final response = await _client.post(
      _authUrl('/auth/v1/signup'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 300) {
      throw ApiException(
        (body['msg'] ?? body['error_description'] ?? 'Sign up failed')
            as String,
        statusCode: response.statusCode,
      );
    }

    if (body['access_token'] == null) {
      throw const EmailConfirmationRequiredException();
    }

    return AuthSession.fromSupabaseJson(body);
  }

  Future<AuthSession> signIn(String email, String password) async {
    final response = await _client.post(
      _authUrl('/auth/v1/token?grant_type=password'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 300) {
      throw ApiException(
        (body['msg'] ?? body['error_description'] ?? 'Sign in failed')
            as String,
        statusCode: response.statusCode,
      );
    }

    return AuthSession.fromSupabaseJson(body);
  }

  /// Sets the current user's password — used to finish account setup after
  /// an invite redirect, where Supabase has authenticated the browser but no
  /// password has ever been set.
  Future<void> updatePassword(String accessToken, String newPassword) async {
    final response = await _client.put(
      _authUrl('/auth/v1/user'),
      headers: {..._headers, 'Authorization': 'Bearer $accessToken'},
      body: jsonEncode({'password': newPassword}),
    );

    if (response.statusCode >= 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        (body['msg'] ?? body['error_description'] ?? 'Could not set password')
            as String,
        statusCode: response.statusCode,
      );
    }
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _client.post(
      _authUrl('/auth/v1/token?grant_type=refresh_token'),
      headers: _headers,
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 300) {
      throw ApiException(
        (body['msg'] ?? body['error_description'] ?? 'Token refresh failed')
            as String,
        statusCode: response.statusCode,
      );
    }

    return AuthSession.fromSupabaseJson(body);
  }
}
