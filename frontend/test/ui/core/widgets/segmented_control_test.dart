import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/core/widgets/segmented_control.dart';

void main() {
  testWidgets('renders a label per segment and reports taps via onChanged', (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSegmentedControl<String>(
            selected: 'a',
            onChanged: (value) => selected = value,
            segments: const [
              AppSegment(value: 'a', label: 'Balances'),
              AppSegment(value: 'b', label: 'Statement'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Balances'), findsOneWidget);
    expect(find.text('Statement'), findsOneWidget);

    await tester.tap(find.text('Statement'));
    await tester.pump();

    expect(selected, 'b');
  });
}
