import 'package:flutter/material.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/household_repository.dart';
import '../../../core/formatting/role_label.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/accept_invite_view_model.dart';

class AcceptInviteView extends StatefulWidget {
  const AcceptInviteView({
    super.key,
    required this.authRepository,
    required this.householdRepository,
    required this.inviteId,
    required this.onAccepted,
  });

  final AuthRepository authRepository;
  final HouseholdRepository householdRepository;
  final String inviteId;
  final void Function(String householdId, String householdName) onAccepted;

  @override
  State<AcceptInviteView> createState() => _AcceptInviteViewState();
}

class _AcceptInviteViewState extends State<AcceptInviteView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final _viewModel = AcceptInviteViewModel(
    authRepository: widget.authRepository,
    householdRepository: widget.householdRepository,
    inviteId: widget.inviteId,
  )..load();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    final result = _viewModel.result;
    if (result != null) {
      widget.onAccepted(result.householdId, result.householdName);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await _viewModel.submit(_passwordController.text);
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
                final preview = _viewModel.preview;

                if (_viewModel.isLoading && preview == null) {
                  return const LoadingState();
                }

                if (preview == null) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorBanner(
                        message:
                            _viewModel.errorMessage ??
                            'Não foi possível encontrar este convite.',
                      ),
                    ],
                  );
                }

                if (preview.accepted) {
                  return const AppEmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Este convite já foi aceito',
                    body: 'Faça login.',
                  );
                }

                if (preview.expired) {
                  return const AppEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Este convite expirou',
                    body: 'Peça ao responsável pela família para convidar você novamente.',
                  );
                }

                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Você foi convidado para',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '${preview.householdName} (${roleLabel(preview.role)})',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ErrorBanner(message: _viewModel.errorMessage),
                      const Text(
                        'Defina uma senha para concluir a criação da sua conta.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('accept_invite_password_field'),
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                        ),
                        validator: (value) =>
                            (value == null || value.length < 8)
                            ? 'Use pelo menos 8 caracteres'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('accept_invite_confirm_password_field'),
                        controller: _confirmController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar senha',
                        ),
                        validator: (value) => value != _passwordController.text
                            ? 'As senhas não coincidem'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      LoadingButton(
                        label: 'Entrar na família',
                        isLoading: _viewModel.isSubmitting,
                        onPressed: _submit,
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
