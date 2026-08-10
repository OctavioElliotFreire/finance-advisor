import 'package:flutter/material.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/member_access_view_model.dart';

class MemberAccessView extends StatefulWidget {
  const MemberAccessView({
    super.key,
    required this.householdRepository,
    required this.householdId,
    required this.memberId,
    required this.memberEmail,
  });

  final HouseholdRepository householdRepository;
  final String householdId;
  final String memberId;
  final String memberEmail;

  @override
  State<MemberAccessView> createState() => _MemberAccessViewState();
}

class _MemberAccessViewState extends State<MemberAccessView> {
  late final _viewModel = MemberAccessViewModel(
    householdRepository: widget.householdRepository,
    householdId: widget.householdId,
    memberId: widget.memberId,
  )..load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final success = await _viewModel.save();
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Acesso atualizado.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.memberEmail} · Acesso')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading && _viewModel.entries.isEmpty) {
            return const LoadingState();
          }

          return Column(
            children: [
              ErrorBanner(message: _viewModel.errorMessage),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Escolha quais bancos conectados este membro pode ver.',
                ),
              ),
              Expanded(
                child: _viewModel.entries.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.account_balance_outlined,
                        title: 'Nenhuma conexão nesta família ainda',
                      )
                    : ListView(
                        children: [
                          for (final entry in _viewModel.entries)
                            CheckboxListTile(
                              title: Text(entry.pluggyItemId),
                              subtitle: Text(entry.status),
                              value: entry.granted,
                              onChanged: (value) => _viewModel.toggle(
                                entry.connectionId,
                                value ?? false,
                              ),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LoadingButton(
                  label: 'Salvar',
                  isLoading: _viewModel.isSaving,
                  onPressed: _save,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
