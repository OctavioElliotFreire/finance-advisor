import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/core/widgets/member_dot.dart';

void main() {
  testWidgets('renders the given color at the default 10x10 size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MemberDot(color: Colors.purple))),
    );

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.color, Colors.purple);
    expect(tester.getSize(find.byType(Container)), const Size(10, 10));
  });

  testWidgets('honors a custom size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MemberDot(color: Colors.teal, size: 16))),
    );

    expect(tester.getSize(find.byType(Container)), const Size(16, 16));
  });
}
