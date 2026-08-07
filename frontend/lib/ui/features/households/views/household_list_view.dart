import 'package:flutter/material.dart';

import '../../../../data/models/household.dart';
import '../../../../data/repositories/household_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/household_view_model.dart';

class HouseholdListView extends StatefulWidget {
  const HouseholdListView({
    super.key,
    required this.householdRepository,
    required this.onLogout,
    required this.onHouseholdSelected,
  });

  final HouseholdRepository householdRepository;
  final VoidCallback onLogout;
  final ValueChanged<Household> onHouseholdSelected;

  @override
  State<HouseholdListView> createState() => _HouseholdListViewState();
}

class _HouseholdListViewState extends State<HouseholdListView> {
  late final _viewModel = HouseholdViewModel(
    householdRepository: widget.householdRepository,
  )..load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _showCreateDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create household'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Household name'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Enter a household name' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _viewModel.create(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your households'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
            tooltip: 'Log out',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading && _viewModel.households.isEmpty) {
            return const LoadingState();
          }

          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(message: _viewModel.errorMessage),
                if (_viewModel.households.isEmpty && !_viewModel.isLoading)
                  const AppEmptyState(
                    icon: Icons.house_outlined,
                    title: 'No households yet',
                    body: 'Create one to get started.',
                  ),
                for (final household in _viewModel.households)
                  Card(
                    child: ListTile(
                      title: Text(household.name),
                      subtitle: Text('Role: ${household.role}'),
                      onTap: () => widget.onHouseholdSelected(household),
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
