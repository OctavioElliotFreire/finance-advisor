import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/core/widgets/member_filter_chips.dart';

void main() {
  testWidgets('renders a chip per member and reports taps via onToggle', (tester) async {
    String? toggledId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberFilterChips(
            onToggle: (id) => toggledId = id,
            members: const [
              MemberFilterOption(id: 'davi', label: 'Davi', color: Colors.purple, selected: true),
              MemberFilterOption(id: 'ana', label: 'Ana', color: Colors.teal, selected: false),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Davi'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);

    await tester.tap(find.text('Ana'));
    await tester.pump();

    expect(toggledId, 'ana');
  });
}
