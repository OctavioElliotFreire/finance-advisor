import 'package:flutter/material.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../core/widgets/error_banner.dart';
import '../view_models/members_view_model.dart';

class MembersView extends StatefulWidget {
  const MembersView({
    super.key,
    required this.householdRepository,
    required this.householdId,
    required this.householdName,
  });

  final HouseholdRepository householdRepository;
  final String householdId;
  final String householdName;

  @override
  State<MembersView> createState() => _MembersViewState();
}

class _MembersViewState extends State<MembersView> {
  late final _viewModel = MembersViewModel(
    householdRepository: widget.householdRepository,
    householdId: widget.householdId,
  )..load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _showInviteDialog() async {
    final emailController = TextEditingController();
    String role = 'member';

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                  DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => role = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop((emailController.text.trim(), role)),
              child: const Text('Invite'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.$1.isNotEmpty) {
      await _viewModel.inviteMember(result.$1, result.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.householdName} — Members')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Invite member'),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading && _viewModel.members.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(message: _viewModel.errorMessage),
                if (_viewModel.members.isEmpty && !_viewModel.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('No members yet.')),
                  ),
                for (final member in _viewModel.members)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(member.email),
                      subtitle: Text('Role: ${member.role}'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
