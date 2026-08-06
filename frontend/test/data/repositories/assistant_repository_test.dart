import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:frontend/data/models/assistant_message.dart';
import 'package:frontend/data/repositories/assistant_repository.dart';
import 'package:frontend/data/repositories/auth_repository.dart';
import 'package:frontend/data/services/backend_api_service.dart';

@GenerateNiceMocks([
  MockSpec<AuthRepository>(),
  MockSpec<BackendApiService>(),
])
import 'assistant_repository_test.mocks.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockBackendApiService backendService;
  late AssistantRepository repository;

  final message = AssistantMessage(
    id: 'msg-1',
    question: 'How much did I spend on Food?',
    answer: 'You spent R\$50 on Food this month.',
    askedByEmail: 'test@example.com',
    createdAt: DateTime(2026, 8, 3),
  );

  setUp(() {
    authRepository = MockAuthRepository();
    backendService = MockBackendApiService();
    repository = AssistantRepository(
      authRepository: authRepository,
      backendService: backendService,
    );
    when(authRepository.getValidAccessToken()).thenAnswer((_) async => 'token-1');
  });

  test('getHistory forwards the token and household id', () async {
    when(backendService.getAssistantMessages('token-1', 'household-1'))
        .thenAnswer((_) async => [message]);

    final result = await repository.getHistory('household-1');

    expect(result.single.question, 'How much did I spend on Food?');
  });

  test('ask forwards the token, household id and question', () async {
    when(backendService.askAssistant('token-1', 'household-1', 'How much did I spend on Food?'))
        .thenAnswer((_) async => message);

    final result = await repository.ask('household-1', 'How much did I spend on Food?');

    expect(result.answer, 'You spent R\$50 on Food this month.');
  });
}
