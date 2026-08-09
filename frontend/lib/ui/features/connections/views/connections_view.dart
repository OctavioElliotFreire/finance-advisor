import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/web/open_pluggy_connect_stub.dart'
    if (dart.library.html) '../../../../core/web/open_pluggy_connect_web.dart';
import '../../../../data/models/pluggy_connection.dart';
import '../../../../data/repositories/connection_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../view_models/connections_view_model.dart';
import 'pluggy_connect_screen.dart';

class ConnectionsView extends StatefulWidget {
  const ConnectionsView({
    super.key,
    required this.connectionRepository,
    required this.householdId,
    required this.householdName,
    this.currentUserEmail,
  });

  final ConnectionRepository connectionRepository;
  final String householdId;
  final String householdName;
  final String? currentUserEmail;

  @override
  State<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends State<ConnectionsView> {
  late final _viewModel = ConnectionsViewModel(
    connectionRepository: widget.connectionRepository,
    householdId: widget.householdId,
  )..load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  List<_ConnectionGroup> _groupByMember(List<PluggyConnection> connections) {
    final byEmail = <String?, List<PluggyConnection>>{};
    for (final connection in connections) {
      byEmail.putIfAbsent(connection.createdByEmail, () => []).add(connection);
    }

    final currentUserEmail = widget.currentUserEmail;
    final otherEmails =
        byEmail.keys
            .whereType<String>()
            .where((email) => email != currentUserEmail)
            .toList()
          ..sort();

    return [
      if (byEmail.containsKey(currentUserEmail) && currentUserEmail != null)
        _ConnectionGroup('You', byEmail[currentUserEmail]!),
      for (final email in otherEmails) _ConnectionGroup(email, byEmail[email]!),
      if (byEmail.containsKey(null))
        _ConnectionGroup('Unknown', byEmail[null]!),
    ];
  }

  Future<void> _connect() async {
    final token = await _viewModel.requestConnectToken();
    if (token == null || !mounted) return;

    String? itemId;
    if (kIsWeb) {
      try {
        itemId = await openPluggyConnectWeb(token);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open the connection widget. Please try again.',
              ),
            ),
          );
        }
        return;
      }
    } else {
      itemId = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PluggyConnectScreen(connectToken: token),
        ),
      );
    }

    if (itemId != null && mounted) {
      await _viewModel.registerConnection(itemId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.householdName} — Connections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _connect,
        icon: const Icon(Icons.add_link),
        label: const Text('Connect institution'),
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading && _viewModel.connections.isEmpty) {
            return const LoadingState();
          }

          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(message: _viewModel.errorMessage),
                if (_viewModel.connections.isEmpty && !_viewModel.isLoading)
                  const AppEmptyState(
                    icon: Icons.account_balance_outlined,
                    title: 'No institutions connected yet',
                    body: 'Connect a bank to start syncing your finances.',
                  ),
                for (final group in _groupByMember(_viewModel.connections)) ...[
                  SectionHeader(title: group.label),
                  for (final connection in group.connections)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.account_balance),
                        title: Text(connection.pluggyItemId),
                        trailing: StatusChip.connectionStatus(
                          connection.status,
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

class _ConnectionGroup {
  const _ConnectionGroup(this.label, this.connections);

  final String label;
  final List<PluggyConnection> connections;
}
