import 'package:flutter/material.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_button.dart';
import '../view_models/auth_view_model.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({
    super.key,
    required this.authRepository,
    required this.onRegistered,
    required this.onNavigateToLogin,
  });

  final AuthRepository authRepository;
  final VoidCallback onRegistered;
  final VoidCallback onNavigateToLogin;

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final _viewModel = AuthViewModel(authRepository: widget.authRepository);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await _viewModel.register(
      _emailController.text,
      _passwordController.text,
    );
    if (success && !_viewModel.needsEmailConfirmation && mounted) {
      widget.onRegistered();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                if (_viewModel.needsEmailConfirmation) {
                  return AppEmptyState(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Check your email',
                    body: 'Confirm your account, then log in.',
                    action: TextButton(
                      onPressed: widget.onNavigateToLogin,
                      child: const Text('Back to login'),
                    ),
                  );
                }
                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create your account',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ErrorBanner(message: _viewModel.errorMessage),
                      TextFormField(
                        key: const Key('register_email_field'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) => (value == null || !value.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('register_password_field'),
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: (value) => (value == null || value.length < 8)
                            ? 'Use at least 8 characters'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      LoadingButton(
                        label: 'Register',
                        isLoading: _viewModel.isLoading,
                        onPressed: _submit,
                      ),
                      TextButton(
                        onPressed: widget.onNavigateToLogin,
                        child: const Text('Already have an account? Log in'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
