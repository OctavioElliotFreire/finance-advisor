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
    testWidgets('maps null to Nunca sincronizado', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus(null)));
      expect(find.text('Nunca sincronizado'), findsOneWidget);
    });

    testWidgets('maps completed to Sincronizado', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus('completed')));
      expect(find.text('Sincronizado'), findsOneWidget);
    });

    testWidgets('maps partially_completed to Sincronizado parcialmente', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus('partially_completed')));
      expect(find.text('Sincronizado parcialmente'), findsOneWidget);
    });

    testWidgets('maps failed to Falha na sincronização', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus('failed')));
      expect(find.text('Falha na sincronização'), findsOneWidget);
    });

    testWidgets('maps running to Sincronizando…', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus('running')));
      expect(find.text('Sincronizando…'), findsOneWidget);
    });

    testWidgets('falls back to the raw status for unknown values', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.syncStatus('weird')));
      expect(find.text('weird'), findsOneWidget);
    });
  });

  group('StatusChip.connectionStatus', () {
    testWidgets('maps pending to Aguardando primeira sincronização', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.connectionStatus('pending')));
      expect(find.text('Aguardando primeira sincronização'), findsOneWidget);
    });

    testWidgets('maps UPDATED to Ativo', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.connectionStatus('UPDATED')));
      expect(find.text('Ativo'), findsOneWidget);
    });

    testWidgets('maps LOGIN_ERROR to Erro de login', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.connectionStatus('LOGIN_ERROR')));
      expect(find.text('Erro de login'), findsOneWidget);
    });

    testWidgets('maps WAITING_USER_INPUT to Requer atenção', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.connectionStatus('WAITING_USER_INPUT')));
      expect(find.text('Requer atenção'), findsOneWidget);
    });

    testWidgets('is case-insensitive', (tester) async {
      await tester.pumpWidget(_withTheme(StatusChip.connectionStatus('updated')));
      expect(find.text('Ativo'), findsOneWidget);
    });
  });
}
