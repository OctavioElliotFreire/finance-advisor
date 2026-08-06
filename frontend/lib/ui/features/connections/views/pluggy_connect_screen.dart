import 'package:flutter/material.dart';
import 'package:flutter_pluggy_connect/flutter_pluggy_connect.dart';

import '../../../../core/config/app_config.dart';

/// Wraps the official `flutter_pluggy_connect` widget. Pops with the
/// resulting Pluggy item id on success, or `null` on error/close.
///
/// Payload shape verified against the package source (v3.0.1,
/// lib/src/pluggy_connect.dart): onSuccess receives
/// `{'item': {'id': ..., 'status': ..., 'executionStatus': ...}}`.
class PluggyConnectScreen extends StatelessWidget {
  const PluggyConnectScreen({super.key, required this.connectToken});

  final String connectToken;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect your institution')),
      body: PluggyConnect(
        connectToken: connectToken,
        language: 'en',
        includeSandbox: AppConfig.pluggyIncludeSandbox,
        onSuccess: (data) {
          final itemId = (data as Map?)?['item']?['id'] as String?;
          Navigator.of(context).pop(itemId);
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection failed. Please try again.')),
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
