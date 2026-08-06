import 'package:flutter/foundation.dart';

import '../../../../data/models/assistant_message.dart';
import '../../../../data/repositories/assistant_repository.dart';
import '../../../../data/services/api_exception.dart';

class AssistantViewModel extends ChangeNotifier {
  AssistantViewModel({
    required AssistantRepository assistantRepository,
    required String householdId,
  }) : _assistantRepository = assistantRepository,
       _householdId = householdId;

  final AssistantRepository _assistantRepository;
  final String _householdId;

  List<AssistantMessage> _messages = const [];
  bool _isLoading = false;
  bool _isAsking = false;
  String? _errorMessage;

  List<AssistantMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isAsking => _isAsking;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _messages = await _assistantRepository.getHistory(_householdId);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Could not load the assistant history.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ask(String question) async {
    _isAsking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final message = await _assistantRepository.ask(_householdId, question);
      _messages = [..._messages, message];
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Could not ask the assistant right now.';
    } finally {
      _isAsking = false;
      notifyListeners();
    }
  }
}
