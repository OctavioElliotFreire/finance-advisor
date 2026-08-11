import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/ui/core/widgets/category_pill.dart';

void main() {
  testWidgets('renders the label in a neutral, uncolored pill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: CategoryPill(label: 'Mercado')),
      ),
    );

    expect(find.text('Mercado'), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.light.colorScheme.surfaceContainerHighest);

    final text = tester.widget<Text>(find.text('Mercado'));
    expect(text.style?.color, AppTheme.light.colorScheme.onSurfaceVariant);
  });
}
