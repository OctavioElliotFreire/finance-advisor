import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/core/widgets/status_chip.dart';
import 'package:frontend/ui/features/family/widgets/connection_health_row.dart';

void main() {
  testWidgets('renders the label and status text for every tone', (tester) async {
    for (final tone in StatusTone.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionHealthRow(label: 'Itaú ••7257', statusText: 'Updated 2h ago', tone: tone),
          ),
        ),
      );

      expect(find.text('Itaú ••7257'), findsOneWidget, reason: 'tone: $tone');
      expect(find.text('Updated 2h ago'), findsOneWidget, reason: 'tone: $tone');
    }
  });
}
