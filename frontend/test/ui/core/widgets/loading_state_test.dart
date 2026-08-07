import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/core/widgets/loading_state.dart';

void main() {
  testWidgets('renders a spinner with no message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LoadingState())),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders a spinner plus message when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LoadingState(message: 'Loading household…')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading household…'), findsOneWidget);
  });
}
