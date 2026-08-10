import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/ui/core/widgets/severity_chip.dart';

Widget _withTheme(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
}

void main() {
  testWidgets('maps high to Alta', (tester) async {
    await tester.pumpWidget(_withTheme(const SeverityChip(severity: 'high')));
    expect(find.text('Alta'), findsOneWidget);
  });

  testWidgets('maps medium to Média', (tester) async {
    await tester.pumpWidget(_withTheme(const SeverityChip(severity: 'medium')));
    expect(find.text('Média'), findsOneWidget);
  });

  testWidgets('maps low to Baixa', (tester) async {
    await tester.pumpWidget(_withTheme(const SeverityChip(severity: 'low')));
    expect(find.text('Baixa'), findsOneWidget);
  });

  testWidgets('falls back to the raw severity for unknown values', (tester) async {
    await tester.pumpWidget(_withTheme(const SeverityChip(severity: 'unknown')));
    expect(find.text('unknown'), findsOneWidget);
  });
}
