import 'package:flutter/material.dart';

import '../../../../data/repositories/household_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/section_header.dart';
import '../view_models/members_view_model.dart';

class MembersView extends StatefulWidget {
  const MembersView({
    super.key,
    required this.householdRepository,
    required this.householdId,
    required this.householdName,
    this.currentUserEmail,
    this.onManageAccess,
  });

  final HouseholdRepository householdRepository;
  final String householdId;
  final String householdName;
  final String? currentUserEmail;
  final void Function(String memberId, String memberEmail)? onManageAccess;

  @override
  State<MembersView> createState() => _MembersViewState();
}

class _MembersViewState extends State<MembersView> {
  late final _viewModel = MembersViewModel(
    householdRepository: widget.householdRepository,
    householdId: widget.householdId,
  )..load();

  final _inviteFormKey = GlobalKey<FormState>();
  final _inviteEmailController = TextEditingController();
  String _inviteRole = 'member';
  bool _isInviting = false;

  @override
  void dispose() {
    _viewModel.dispose();
    _inviteEmailController.dispose();
    super.dispose();
  }

  void _toggleInviteForm() {
    setState(() {
      _isInviting = !_isInviting;
      if (!_isInviting) {
        _inviteEmailController.clear();
        _inviteRole = 'member';
      }
    });
  }

  Future<void> _submitInvite() async {
    if (!_inviteFormKey.currentState!.validate()) return;
    final email = _inviteEmailController.text.trim();
    final outcome = await _viewModel.inviteMember(email, _inviteRole);
    if (outcome != null && mounted) {
      setState(() {
        _isInviting = false;
        _inviteEmailController.clear();
        _inviteRole = 'member';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome == 'added'
                ? '$email was added to the household.'
                : 'Invite email sent to $email.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.householdName} — Members')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleInviteForm,
        icon: Icon(_isInviting ? Icons.close : Icons.person_add),
        label: Text(_isInviting ? 'Cancel' : 'Invite member'),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading && _viewModel.members.isEmpty) {
            return const LoadingState();
          }

          final isOwner =
              widget.currentUserEmail != null &&
              _viewModel.members.any(
                (m) => m.email == widget.currentUserEmail && m.role == 'owner',
              );

          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(message: _viewModel.errorMessage),
                if (_isInviting)
                  _InviteMemberForm(
                    formKey: _inviteFormKey,
                    emailController: _inviteEmailController,
                    role: _inviteRole,
                    onRoleChanged: (value) =>
                        setState(() => _inviteRole = value),
                    onSubmit: _submitInvite,
                    onCancel: _toggleInviteForm,
                  ),
                if (_viewModel.members.isEmpty && !_viewModel.isLoading)
                  const AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'No members yet',
                  ),
                for (final member in _viewModel.members)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(member.email),
                      subtitle: Text('Role: ${member.role}'),
                      trailing: isOwner && member.role != 'owner'
                          ? IconButton(
                              icon: const Icon(Icons.tune),
                              tooltip: 'Manage access',
                              onPressed: () => widget.onManageAccess?.call(
                                member.id,
                                member.email,
                              ),
                            )
                          : null,
                    ),
                  ),
                if (_viewModel.pendingInvites.isNotEmpty) ...[
                  const SectionHeader(title: 'Pending invites'),
                  for (final invite in _viewModel.pendingInvites)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.hourglass_empty),
                        title: Text(invite.email),
                        subtitle: Text(
                          'Role: ${invite.role} · not yet accepted',
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InviteMemberForm extends StatelessWidget {
  const _InviteMemberForm({
    required this.formKey,
    required this.emailController,
    required this.role,
    required this.onRoleChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final String role;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite member',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Enter a valid email'
                    : null,
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
                  if (value != null) onRoleChanged(value);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onSubmit,
                    child: const Text('Invite'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
