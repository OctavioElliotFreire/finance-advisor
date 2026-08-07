import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/core/widgets/section_header.dart';

void main() {
  testWidgets('renders the title with no trailing widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SectionHeader(title: 'Pending invites'))),
    );

    expect(find.text('Pending invites'), findsOneWidget);
  });

  testWidgets('renders the trailing widget when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SectionHeader(title: 'You', trailing: Icon(Icons.check))),
      ),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
