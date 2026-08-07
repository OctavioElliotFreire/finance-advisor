import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/ui/core/widgets/status_chip.dart';

Widget _withTheme(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
}

void main() {
  testWidgets('renders one chip per StatusTone', (tester) async {
    for (final tone in StatusTone.values) {
      await tester.pumpWidget(_withTheme(StatusChip(label: 'Label', tone: tone)));
      expect(find.text('Label'), findsOneWidget, reason: 'tone: $tone');
    }
  });

  group('StatusChip.syncStatus', () {
    testWidgets('maps null to Never synced', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus(null)));
      expect(find.text('Never synced'), findsOneWidget);
    });

    testWidgets('maps completed to Synced', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus('completed')));
      expect(find.text('Synced'), findsOneWidget);
    });

    testWidgets('maps partially_completed to Partially synced', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus('partially_completed')));
      expect(find.text('Partially synced'), findsOneWidget);
    });

    testWidgets('maps failed to Sync failed', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus('failed')));
      expect(find.text('Sync failed'), findsOneWidget);
    });

    testWidgets('maps running to Syncing…', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus('running')));
      expect(find.text('Syncing…'), findsOneWidget);
    });

    testWidgets('falls back to the raw status for unknown values', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus('weird')));
      expect(find.text('weird'), findsOneWidget);
    });
  });

  group('StatusChip.connectionStatus', () {
    testWidgets('maps pending to Pending first sync', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.connectionStatus('pending')));
      expect(find.text('Pending first sync'), findsOneWidget);
    });

    testWidgets('maps UPDATED to Active', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.connectionStatus('UPDATED')));
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('maps LOGIN_ERROR to Login error', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.connectionStatus('LOGIN_ERROR')));
      expect(find.text('Login error'), findsOneWidget);
    });

    testWidgets('maps WAITING_USER_INPUT to Needs attention', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.connectionStatus('WAITING_USER_INPUT')));
      expect(find.text('Needs attention'), findsOneWidget);
    });

    testWidgets('is case-insensitive', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.connectionStatus('updated')));
      expect(find.text('Active'), findsOneWidget);
    });
  });
}
