import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/scope_controller.dart';
import 'package:frontend/ui/core/widgets/period_pill.dart';

Widget _withTheme(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the preset label by default', (tester) async {
    final controller = ScopeController(householdId: 'h1');
    await tester.pumpWidget(_withTheme(PeriodPill(controller: controller)));

    expect(find.text('Este mês'), findsOneWidget);
  });

  testWidgets('opens a sheet with all presets and the compare toggle', (tester) async {
    final controller = ScopeController(householdId: 'h1');
    await tester.pumpWidget(_withTheme(PeriodPill(controller: controller)));

    await tester.tap(find.text('Este mês'));
    await tester.pumpAndSettle();

    expect(find.text('Mês passado'), findsOneWidget);
    expect(find.text('Últimos 3 meses'), findsOneWidget);
    expect(find.text('Este ano'), findsOneWidget);
    expect(find.text('Últimos 12 meses'), findsOneWidget);
    expect(find.text('Comparar com período anterior'), findsOneWidget);
  });

  testWidgets('selecting a preset in the sheet updates the controller', (tester) async {
    final controller = ScopeController(householdId: 'h1');
    await tester.pumpWidget(_withTheme(PeriodPill(controller: controller)));

    await tester.tap(find.text('Este mês'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Este ano'));
    await tester.pumpAndSettle();

    expect(controller.preset, PeriodPreset.thisYear);
  });

  testWidgets('tapping the back arrow steps the controller', (tester) async {
    final controller = ScopeController(householdId: 'h1');
    await tester.pumpWidget(_withTheme(PeriodPill(controller: controller)));

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    final range = controller.resolveRange();
    final now = DateTime.now();
    final expectedMonth = DateTime(now.year, now.month - 1, 1);
    expect(range.start, expectedMonth);
  });
}
