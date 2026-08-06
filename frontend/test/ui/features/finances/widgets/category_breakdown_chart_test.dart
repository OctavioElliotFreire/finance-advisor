import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/features/finances/widgets/category_breakdown_chart.dart';
import 'package:frontend/ui/features/finances/widgets/category_breakdown_chart_data.dart';

void main() {
  Future<void> pump(WidgetTester tester, CategoryBreakdownChartData data) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CategoryBreakdownChart(data: data))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a pie slice and legend row per category', (
    tester,
  ) async {
    await pump(
      tester,
      const CategoryBreakdownChartData(
        slices: [
          CategoryBreakdownSlice(label: 'Rent', total: 1500),
          CategoryBreakdownSlice(label: 'Groceries', total: 500),
        ],
      ),
    );

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('renders a single-category slice without throwing', (
    tester,
  ) async {
    await pump(
      tester,
      const CategoryBreakdownChartData(
        slices: [CategoryBreakdownSlice(label: 'Rent', total: 1500)],
      ),
    );

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('renders an empty state without throwing for no categories', (
    tester,
  ) async {
    await pump(tester, const CategoryBreakdownChartData(slices: []));

    expect(find.byType(PieChart), findsNothing);
    expect(find.text('No categorized spending yet.'), findsOneWidget);
  });
}
