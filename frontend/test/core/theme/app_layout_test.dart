import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_layout.dart';
import 'package:frontend/core/theme/app_spacing.dart';

Future<void> _setViewportWidth(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('renders its children', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppGridPage(children: [Text('one'), Text('two')]),
        ),
      ),
    );

    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('uses 16px padding below the wide breakpoint', (tester) async {
    await _setViewportWidth(tester, 800);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppGridPage(children: [Text('content')]))),
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.padding, const EdgeInsets.all(AppSpacing.lg));
  });

  testWidgets('uses 24px padding at/above the wide breakpoint', (tester) async {
    await _setViewportWidth(tester, kWideBreakpoint);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppGridPage(children: [Text('content')]))),
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.padding, const EdgeInsets.all(AppSpacing.xl));
  });

  testWidgets('clamps content width to kMaxContentWidth on a wider surface', (tester) async {
    await _setViewportWidth(tester, 1440);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppGridPage(children: [Text('content')]))),
    );

    final size = tester.getSize(find.byType(ListView));
    expect(size.width, kMaxContentWidth);
  });
}
