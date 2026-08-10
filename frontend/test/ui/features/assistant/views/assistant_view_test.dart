import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/assistant_message.dart';
import 'package:frontend/data/models/auth_session.dart';
import 'package:frontend/data/models/me.dart';
import 'package:frontend/data/repositories/assistant_repository.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/services/api_exception.dart';
import 'package:frontend/data/services/backend_api_service.dart';
import 'package:frontend/data/services/secure_token_storage.dart';
import 'package:frontend/data/services/supabase_auth_service.dart';
import 'package:frontend/ui/features/assistant/views/assistant_view.dart';

class _FakeAuthService extends SupabaseAuthService {
  @override
  Future<AuthSession> signIn(String email, String password) async {
    return AuthSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      userId: 'user-1',
      email: email,
    );
  }
}

class _FakeStorage extends SecureTokenStorage {
  @override
  Future<void> saveSession(AuthSession session) async {}

  @override
  Future<AuthSession?> readSession() async => null;

  @override
  Future<void> clear() async {}
}

class _FakeBackendService extends BackendApiService {
  _FakeBackendService({
    this.initialMessages = const [],
    this.askError,
    Completer<AssistantMessage>? askCompleter,
  }) : _askCompleter = askCompleter;

  final List<AssistantMessage> initialMessages;
  final ApiException? askError;
  final Completer<AssistantMessage>? _askCompleter;

  @override
  Future<Me> getMe(String accessToken) async {
    return Me(id: 'user-1', email: 'owner@example.com', createdAt: DateTime.now().toUtc());
  }

  @override
  Future<List<AssistantMessage>> getAssistantMessages(
    String accessToken,
    String householdId,
  ) async {
    return initialMessages;
  }

  @override
  Future<AssistantMessage> askAssistant(
    String accessToken,
    String householdId,
    String question,
  ) async {
    if (askError != null) throw askError!;
    if (_askCompleter != null) return _askCompleter.future;
    return AssistantMessage(
      id: 'msg-new',
      question: question,
      answer: 'You spent R\$50 on Food this month.',
      askedByEmail: 'owner@example.com',
      createdAt: DateTime.now().toUtc(),
    );
  }
}

Future<AssistantRepository> _buildRepository(_FakeBackendService backendService) async {
  final authRepository = AuthRepository(
    authService: _FakeAuthService(),
    backendService: backendService,
    storage: _FakeStorage(),
  );
  await authRepository.login('owner@example.com', 'hunter22');
  return AssistantRepository(authRepository: authRepository, backendService: backendService);
}

void main() {
  testWidgets('renders existing assistant history', (tester) async {
    final repository = await _buildRepository(
      _FakeBackendService(
        initialMessages: [
          AssistantMessage(
            id: 'msg-1',
            question: 'How much did I spend on Food?',
            answer: 'You spent R\$50 on Food this month.',
            askedByEmail: 'owner@example.com',
            createdAt: DateTime.now().toUtc(),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantView(
          assistantRepository: repository,
          householdId: 'household-1',
          householdName: 'Elliot Family',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How much did I spend on Food?'), findsOneWidget);
    expect(find.text('You spent R\$50 on Food this month.'), findsOneWidget);
  });

  testWidgets('submitting a question shows the new answer', (tester) async {
    final repository = await _buildRepository(_FakeBackendService());

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantView(
          assistantRepository: repository,
          householdId: 'household-1',
          householdName: 'Elliot Family',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'How much did I spend on Food?');
    await tester.tap(find.text('Perguntar'));
    await tester.pumpAndSettle();

    expect(find.text('How much did I spend on Food?'), findsOneWidget);
    expect(find.text('You spent R\$50 on Food this month.'), findsOneWidget);
  });

  testWidgets('shows a loading indicator while a question is in flight', (tester) async {
    final completer = Completer<AssistantMessage>();
    final repository = await _buildRepository(
      _FakeBackendService(askCompleter: completer),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantView(
          assistantRepository: repository,
          householdId: 'household-1',
          householdName: 'Elliot Family',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'How much did I spend on Food?');
    await tester.tap(find.text('Perguntar'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      AssistantMessage(
        id: 'msg-new',
        question: 'How much did I spend on Food?',
        answer: 'You spent R\$50 on Food this month.',
        askedByEmail: 'owner@example.com',
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows the backend error message when asking fails', (tester) async {
    final repository = await _buildRepository(
      _FakeBackendService(
        askError: ApiException(
          'This household has reached the limit of 20 questions per hour. Please try again later.',
          statusCode: 429,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AssistantView(
          assistantRepository: repository,
          householdId: 'household-1',
          householdName: 'Elliot Family',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'One more question?');
    await tester.tap(find.text('Perguntar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This household has reached the limit of 20 questions per hour. Please try again later.',
      ),
      findsOneWidget,
    );
  });
}
