import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../data/repositories/connection_repository.dart';
import '../../../core/widgets/error_banner.dart';
import '../view_models/connections_view_model.dart';
import 'pluggy_connect_screen.dart';

class ConnectionsView extends StatefulWidget {
  const ConnectionsView({
    super.key,
    required this.connectionRepository,
    required this.householdId,
    required this.householdName,
  });

  final ConnectionRepository connectionRepository;
  final String householdId;
  final String householdName;

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

  Future<void> _connect() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connecting institutions from the web app is coming soon — use the mobile app for now.',
          ),
        ),
      );
      return;
    }

    final token = await _viewModel.requestConnectToken();
    if (token == null || !mounted) return;

    final itemId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => PluggyConnectScreen(connectToken: token)),
    );

    if (itemId != null) {
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
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(message: _viewModel.errorMessage),
                if (_viewModel.connections.isEmpty && !_viewModel.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text('No institutions connected yet.'),
                    ),
                  ),
                for (final connection in _viewModel.connections)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_balance),
                      title: Text(connection.pluggyItemId),
                      subtitle: Text('Status: ${connection.status}'),
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
