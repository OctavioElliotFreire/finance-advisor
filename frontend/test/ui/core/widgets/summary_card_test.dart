import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/core/widgets/summary_card.dart';

void main() {
  testWidgets('renders label and value with no trailing or child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SummaryCard(label: 'Total balance', value: 'R\$ 1.234,56')),
      ),
    );

    expect(find.text('Total balance'), findsOneWidget);
    expect(find.text('R\$ 1.234,56'), findsOneWidget);
  });

  testWidgets('renders trailing and child when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryCard(
            label: 'Total balance',
            value: 'R\$ 1.234,56',
            trailing: Icon(Icons.sync),
            child: Text('Extra detail'),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(find.text('Extra detail'), findsOneWidget);
  });
}
