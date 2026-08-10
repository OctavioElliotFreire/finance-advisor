import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/features/dashboard/widgets/cash_flow_chart.dart';
import 'package:frontend/ui/features/dashboard/widgets/cash_flow_chart_data.dart';

void main() {
  testWidgets('renders a bar per month with income and expenses', (
    tester,
  ) async {
    const data = CashFlowChartData(
      points: [
        CashFlowChartPoint(monthLabel: 'Jun 2026', income: 5000, expenses: 3200),
        CashFlowChartPoint(monthLabel: 'Jul 2026', income: 5100, expenses: 4000),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CashFlowChart(data: data))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('Entradas'), findsOneWidget);
    expect(find.text('Saídas'), findsOneWidget);
  });

  testWidgets('renders without throwing when there is no data', (
    tester,
  ) async {
    const data = CashFlowChartData(points: []);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CashFlowChart(data: data))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
  });
}
