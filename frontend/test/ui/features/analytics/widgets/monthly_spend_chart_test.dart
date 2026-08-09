import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/features/analytics/widgets/monthly_spend_chart.dart';
import 'package:frontend/ui/features/analytics/widgets/monthly_spend_chart_data.dart';

void main() {
  testWidgets('renders a bar per month', (tester) async {
    const data = MonthlySpendChartData(
      points: [
        MonthlySpendChartPoint(monthLabel: 'Jun 2026', total: 3200),
        MonthlySpendChartPoint(monthLabel: 'Jul 2026', total: 4000),
      ],
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MonthlySpendChart(data: data))));
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('renders a fallback message when there is no data', (tester) async {
    const data = MonthlySpendChartData(points: []);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MonthlySpendChart(data: data))));

    expect(find.byType(BarChart), findsNothing);
    expect(find.text('No spending data yet.'), findsOneWidget);
  });
}
