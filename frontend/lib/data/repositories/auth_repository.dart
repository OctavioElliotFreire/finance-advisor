import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../models/me.dart';
import '../services/backend_api_service.dart';
import '../services/secure_token_storage.dart';
import '../services/supabase_auth_service.dart';

/// Single source of truth for auth state. `ChangeNotifier` so the router can
/// redirect reactively (via `GoRouter(refreshListenable: authRepository)`)
/// whenever login/logout happens.
class AuthRepository extends ChangeNotifier {
  AuthRepository({
    SupabaseAuthService? authService,
    BackendApiService? backendService,
    SecureTokenStorage? storage,
  }) : _authService = authService ?? SupabaseAuthService(),
       _backendService = backendService ?? BackendApiService(),
       _storage = storage ?? SecureTokenStorage();

  final SupabaseAuthService _authService;
  final BackendApiService _backendService;
  final SecureTokenStorage _storage;

  AuthSession? _session;
  Me? _currentUser;
  bool _isRestoring = true;

  bool get isAuthenticated => _session != null;
  bool get isRestoring => _isRestoring;
  Me? get currentUser => _currentUser;

  /// Loads a persisted session (if any) on app start. Must complete before
  /// the router makes its first redirect decision.
  Future<void> restoreSession() async {
    _isRestoring = true;
    notifyListeners();

    final stored = await _storage.readSession();
    if (stored == null) {
      _isRestoring = false;
      notifyListeners();
      return;
    }

    try {
      _session = stored.isExpired
          ? await _authService.refresh(stored.refreshToken)
          : stored;
      if (stored.isExpired) await _storage.saveSession(_session!);
      _currentUser = await _backendService.getMe(_session!.accessToken);
    } catch (_) {
      await _storage.clear();
      _session = null;
      _currentUser = null;
    }

    _isRestoring = false;
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    final session = await _authService.signUp(email, password);
    await _applySession(session);
  }

  Future<void> login(String email, String password) async {
    final session = await _authService.signIn(email, password);
    await _applySession(session);
  }

  Future<void> logout() async {
    await _storage.clear();
    _session = null;
    _currentUser = null;
    notifyListeners();
  }

  /// Returns a non-expired access token, refreshing first if needed. Other
  /// repositories (e.g. households) call this rather than touching
  /// `_session` directly.
  Future<String> getValidAccessToken() async {
    final session = _session;
    if (session == null) {
      throw StateError('No active session');
    }
    if (!session.isExpired) return session.accessToken;

    final refreshed = await _authService.refresh(session.refreshToken);
    await _applySession(refreshed);
    return refreshed.accessToken;
  }

  Future<void> _applySession(AuthSession session) async {
    _session = session;
    await _storage.saveSession(session);
    _currentUser = await _backendService.getMe(session.accessToken);
    notifyListeners();
  }
}
