import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/core/widgets/chart_palette.dart';

void main() {
  testWidgets('renders a colored swatch and label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LegendSwatch(color: Colors.teal, label: 'Income')),
      ),
    );

    expect(find.text('Income'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container));
    expect(container.color, Colors.teal);
  });
}
