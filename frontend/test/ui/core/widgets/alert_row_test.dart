import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/core/widgets/alert_row.dart';
import 'package:frontend/ui/core/widgets/status_chip.dart';

void main() {
  testWidgets('renders title, subtitle and icon for every tone', (tester) async {
    for (final tone in StatusTone.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAlertRow(
              icon: Icons.warning_amber,
              title: 'Possible duplicate charge',
              subtitle: 'Ana · SmartFit',
              tone: tone,
            ),
          ),
        ),
      );

      expect(find.text('Possible duplicate charge'), findsOneWidget, reason: 'tone: $tone');
      expect(find.text('Ana · SmartFit'), findsOneWidget, reason: 'tone: $tone');
      expect(find.byIcon(Icons.warning_amber), findsOneWidget, reason: 'tone: $tone');
    }
  });

  testWidgets('renders without a subtitle when none is given', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppAlertRow(icon: Icons.info_outline, title: 'No alerts')),
      ),
    );

    expect(find.text('No alerts'), findsOneWidget);
  });
}
