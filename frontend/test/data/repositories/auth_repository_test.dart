import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseAuthService>(),
  MockSpec<BackendApiService>(),
  MockSpec<SecureTokenStorage>(),
])
import 'auth_repository_test.mocks.dart';

AuthSession _session({required DateTime expiresAt, String token = 'access-1'}) {
  return AuthSession(
    accessToken: token,
    refreshToken: 'refresh-1',
    expiresAt: expiresAt,
    userId: 'user-1',
    email: 'family@example.com',
  );
}

void main() {
  late MockSupabaseAuthService authService;
  late MockBackendApiService backendService;
  late MockSecureTokenStorage storage;
  late AuthRepository repository;

  setUp(() {
    authService = MockSupabaseAuthService();
    backendService = MockBackendApiService();
    storage = MockSecureTokenStorage();
    repository = AuthRepository(
      authService: authService,
      backendService: backendService,
      storage: storage,
    );
  });

  final me = Me(id: 'user-1', email: 'family@example.com', createdAt: DateTime.utc(2026));

  group('restoreSession', () {
    test('leaves the repository unauthenticated when nothing is stored', () async {
      when(storage.readSession()).thenAnswer((_) async => null);

      await repository.restoreSession();

      expect(repository.isAuthenticated, isFalse);
      expect(repository.isRestoring, isFalse);
    });

    test('restores a still-valid session without refreshing', () async {
      final session = _session(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      when(storage.readSession()).thenAnswer((_) async => session);
      when(backendService.getMe(session.accessToken)).thenAnswer((_) async => me);

      await repository.restoreSession();

      expect(repository.isAuthenticated, isTrue);
      expect(repository.currentUser?.email, 'family@example.com');
      verifyNever(authService.refresh(any));
    });

    test('refreshes an expired session before restoring', () async {
      final expired = _session(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );
      final refreshed = _session(
        token: 'access-2',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      when(storage.readSession()).thenAnswer((_) async => expired);
      when(authService.refresh(expired.refreshToken))
          .thenAnswer((_) async => refreshed);
      when(backendService.getMe(refreshed.accessToken)).thenAnswer((_) async => me);

      await repository.restoreSession();

      expect(repository.isAuthenticated, isTrue);
      verify(storage.saveSession(refreshed)).called(1);
    });

    test('clears storage when the stored refresh token is rejected', () async {
      final expired = _session(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );
      when(storage.readSession()).thenAnswer((_) async => expired);
      when(authService.refresh(any)).thenThrow(Exception('refresh rejected'));

      await repository.restoreSession();

      expect(repository.isAuthenticated, isFalse);
      verify(storage.clear()).called(1);
    });
  });

  group('login', () {
    test('persists the session and loads the current user', () async {
      final session = _session(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      when(authService.signIn('family@example.com', 'hunter22'))
          .thenAnswer((_) async => session);
      when(backendService.getMe(session.accessToken)).thenAnswer((_) async => me);

      await repository.login('family@example.com', 'hunter22');

      expect(repository.isAuthenticated, isTrue);
      verify(storage.saveSession(session)).called(1);
    });
  });

  group('logout', () {
    test('clears stored session and auth state', () async {
      await repository.logout();

      expect(repository.isAuthenticated, isFalse);
      verify(storage.clear()).called(1);
    });
  });

  group('getValidAccessToken', () {
    test('throws when there is no active session', () {
      expect(() => repository.getValidAccessToken(), throwsStateError);
    });

    test('returns the cached token without refreshing when still valid', () async {
      final session = _session(
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      when(authService.signIn(any, any)).thenAnswer((_) async => session);
      when(backendService.getMe(any)).thenAnswer((_) async => me);
      await repository.login('family@example.com', 'hunter22');

      final token = await repository.getValidAccessToken();

      expect(token, session.accessToken);
      verifyNever(authService.refresh(any));
    });

    test('refreshes and returns a new token when the cached one is expired', () async {
      final expired = _session(
        expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );
      final refreshed = _session(
        token: 'access-2',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      when(authService.signIn(any, any)).thenAnswer((_) async => expired);
      when(backendService.getMe(any)).thenAnswer((_) async => me);
      await repository.login('family@example.com', 'hunter22');

      when(authService.refresh(expired.refreshToken))
          .thenAnswer((_) async => refreshed);

      final token = await repository.getValidAccessToken();

      expect(token, 'access-2');
    });
  });
}
