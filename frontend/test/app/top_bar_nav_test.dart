import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/household_shell.dart';

void main() {
  testWidgets('renders all 4 destination labels and the brand mark', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopBarNav(
            currentIndex: 0,
            onDestinationSelected: (_) {},
            showPeriod: false,
            periodPill: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    expect(find.text('Family Finance'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Contas'), findsOneWidget);
    expect(find.text('Análises'), findsOneWidget);
    expect(find.text('Família'), findsOneWidget);
  });

  testWidgets('the active index is visually distinguished from the others', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopBarNav(
            currentIndex: 2,
            onDestinationSelected: (_) {},
            showPeriod: false,
            periodPill: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    final active = tester.widget<Text>(find.text('Análises'));
    final inactive = tester.widget<Text>(find.text('Contas'));
    expect(active.style?.fontWeight, FontWeight.bold);
    expect(inactive.style?.fontWeight, isNot(FontWeight.bold));
  });

  testWidgets('tapping a destination invokes onDestinationSelected with its index', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopBarNav(
            currentIndex: 0,
            onDestinationSelected: taps.add,
            showPeriod: false,
            periodPill: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Família'));
    await tester.pump();

    expect(taps, [3]);
  });

  testWidgets('the period pill slot only renders when showPeriod is true', (tester) async {
    Future<void> pumpWith(bool showPeriod) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopBarNav(
            currentIndex: 0,
            onDestinationSelected: (_) {},
            showPeriod: showPeriod,
            periodPill: const Text('PERIOD-PILL-MARKER'),
          ),
        ),
      ),
    );

    await pumpWith(false);
    expect(find.text('PERIOD-PILL-MARKER'), findsNothing);

    await pumpWith(true);
    expect(find.text('PERIOD-PILL-MARKER'), findsOneWidget);
  });
}
