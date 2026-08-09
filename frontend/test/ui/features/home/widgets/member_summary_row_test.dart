import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/features/home/widgets/member_summary_row.dart';

void main() {
  testWidgets('renders name, comparison text and amount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MemberSummaryRow(
            memberName: 'Maia',
            memberColor: Colors.orange,
            comparisonText: '40% above her average',
            comparisonIsWarning: true,
            amount: 'R\$ 1.600,00',
            amountIsWarning: true,
          ),
        ),
      ),
    );

    expect(find.text('Maia'), findsOneWidget);
    expect(find.text('40% above her average'), findsOneWidget);
    expect(find.text('R\$ 1.600,00'), findsOneWidget);
  });

  testWidgets('hides the account-count cell when none is given', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MemberSummaryRow(
            memberName: 'Davi',
            memberColor: Colors.purple,
            comparisonText: 'Within average',
            amount: 'R\$ 3.980,00',
          ),
        ),
      ),
    );

    expect(find.text('Davi'), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('shows the account count when given', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MemberSummaryRow(
            memberName: 'Ana',
            memberColor: Colors.teal,
            accountCount: 2,
            comparisonText: 'Within average',
            amount: 'R\$ 2.870,00',
          ),
        ),
      ),
    );

    expect(find.text('2'), findsOneWidget);
  });
}
