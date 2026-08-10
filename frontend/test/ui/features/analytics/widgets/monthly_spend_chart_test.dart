import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/features/analytics/widgets/monthly_spend_chart.dart';
import 'package:frontend/ui/features/analytics/widgets/monthly_spend_chart_data.dart';

void main() {
  testWidgets('unstacked mode renders a bar per month with no legend', (tester) async {
    const data = MonthlySpendChartData(
      mode: MonthlySpendChartMode.unstacked,
      points: [
        MonthlySpendChartPoint(monthLabel: 'Jun 2026', total: 3200),
        MonthlySpendChartPoint(monthLabel: 'Jul 2026', total: 4000),
      ],
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MonthlySpendChart(data: data))));
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('stacked mode renders a bar per month plus a legend row', (tester) async {
    const data = MonthlySpendChartData(
      mode: MonthlySpendChartMode.stacked,
      points: [
        MonthlySpendChartPoint(
          monthLabel: 'Jul 2026',
          total: 300,
          segments: [
            MonthlySpendSegment(label: 'a@x.com', color: Colors.purple, value: 200),
            MonthlySpendSegment(label: 'Outros', color: Colors.grey, value: 100),
          ],
        ),
      ],
      legend: [
        MonthlySpendSegment(label: 'a@x.com', color: Colors.purple, value: 200),
        MonthlySpendSegment(label: 'Outros', color: Colors.grey, value: 100),
      ],
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MonthlySpendChart(data: data))));
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('a@x.com'), findsOneWidget);
    expect(find.text('Outros'), findsOneWidget);
  });

  testWidgets('ranked-list mode renders no chart, just a ranked list', (tester) async {
    const data = MonthlySpendChartData(
      mode: MonthlySpendChartMode.rankedList,
      rankedTotals: [
        MonthlySpendSegment(label: 'b@x.com', color: Colors.teal, value: 500),
        MonthlySpendSegment(label: 'a@x.com', color: Colors.purple, value: 100),
      ],
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MonthlySpendChart(data: data))));
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsNothing);
    expect(find.text('b@x.com'), findsOneWidget);
    expect(find.text('a@x.com'), findsOneWidget);
  });

  testWidgets('renders a fallback message when there is no data', (tester) async {
    const data = MonthlySpendChartData(mode: MonthlySpendChartMode.unstacked, points: []);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MonthlySpendChart(data: data))));

    expect(find.byType(BarChart), findsNothing);
    expect(find.text('Nenhum dado de gastos ainda.'), findsOneWidget);
  });
}
