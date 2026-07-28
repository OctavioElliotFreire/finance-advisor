import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/api_exception.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  bool _isLoading = false;
  String? _errorMessage;
  bool _needsEmailConfirmation = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get needsEmailConfirmation => _needsEmailConfirmation;

  Future<bool> login(String email, String password) {
    return _run(() => _authRepository.login(email.trim(), password));
  }

  Future<bool> register(String email, String password) {
    return _run(() async {
      try {
        await _authRepository.register(email.trim(), password);
      } on EmailConfirmationRequiredException {
        _needsEmailConfirmation = true;
      }
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    _needsEmailConfirmation = false;
    notifyListeners();

    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
