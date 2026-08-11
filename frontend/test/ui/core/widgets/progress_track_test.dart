import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/ui/core/widgets/progress_track.dart';

void main() {
  testWidgets('renders zero, one, and two segments without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ProgressTrack(segments: []),
              ProgressTrack(segments: [ProgressSegment(fraction: 0.35, color: Colors.black)]),
              ProgressTrack(
                segments: [
                  ProgressSegment(fraction: 0.6, color: Colors.black),
                  ProgressSegment(fraction: 0.2, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(ProgressTrack), findsNWidgets(3));
  });

  testWidgets('clamps a fraction sum over 1.0 without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProgressTrack(
            segments: [
              ProgressSegment(fraction: 0.8, color: Colors.black),
              ProgressSegment(fraction: 0.8, color: Colors.grey),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(ProgressTrack), findsOneWidget);
  });

  testWidgets('default trackColor resolves to the theme surfaceContainerHighest', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ProgressTrack(segments: []),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(of: find.byType(ProgressTrack), matching: find.byType(Container)).first,
    );
    expect(container.color, AppTheme.light.colorScheme.surfaceContainerHighest);
  });

  testWidgets('an explicit trackColor overrides the theme default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ProgressTrack(segments: [], trackColor: Colors.purple),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.descendant(of: find.byType(ProgressTrack), matching: find.byType(Container)).first,
    );
    expect(container.color, Colors.purple);
  });
}
