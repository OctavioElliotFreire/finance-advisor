import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/ui/core/widgets/severity_chip.dart';

Widget _withTheme(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
}

void main() {
  testWidgets('maps high to High', (tester) async {
    await tester.pumpWidget(_withTheme(const SeverityChip(severity: 'high')));
    expect(find.text('High'), findsOneWidget);
  });

  testWidgets('maps medium to Medium', (tester) async {
    await tester.pumpWidget(_withTheme(const SeverityChip(severity: 'medium')));
    expect(find.text('Medium'), findsOneWidget);
  });

  testWidgets('maps low to Low', (tester) async {
    await tester.pumpWidget(_withTheme(const SeverityChip(severity: 'low')));
    expect(find.text('Low'), findsOneWidget);
  });

  testWidgets('falls back to the raw severity for unknown values', (tester) async {
    await tester.pumpWidget(_withTheme(const SeverityChip(severity: 'unknown')));
    expect(find.text('unknown'), findsOneWidget);
  });
}
