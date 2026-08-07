import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/core/widgets/empty_state.dart';

void main() {
  testWidgets('renders icon and title with no body or action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(icon: Icons.inbox_outlined, title: 'Nothing here yet'),
        ),
      ),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('renders body text and action when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.account_balance_outlined,
            title: 'No institutions connected yet',
            body: 'Connect a bank to start syncing.',
            action: ElevatedButton(onPressed: () {}, child: const Text('Connect institution')),
          ),
        ),
      ),
    );

    expect(find.text('No institutions connected yet'), findsOneWidget);
    expect(find.text('Connect a bank to start syncing.'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Connect institution'), findsOneWidget);
  });
}
