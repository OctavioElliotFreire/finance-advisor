import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/features/finances/widgets/balance_history_chart.dart';
import 'package:frontend/ui/features/finances/widgets/balance_history_chart_data.dart';

void main() {
  Future<void> pump(WidgetTester tester, BalanceHistoryChartData data) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: BalanceHistoryChart(data: data))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a line for a populated series', (tester) async {
    await pump(
      tester,
      const BalanceHistoryChartData(
        points: [
          BalanceHistoryChartPoint(dateLabel: '6/1/2026', balance: 1000),
          BalanceHistoryChartPoint(dateLabel: '7/1/2026', balance: 1200),
          BalanceHistoryChartPoint(dateLabel: '8/1/2026', balance: 900),
        ],
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('renders a single-point series without throwing', (
    tester,
  ) async {
    await pump(
      tester,
      const BalanceHistoryChartData(
        points: [BalanceHistoryChartPoint(dateLabel: '6/1/2026', balance: 1000)],
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('renders an empty state without throwing for an empty series', (
    tester,
  ) async {
    await pump(tester, const BalanceHistoryChartData(points: []));

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Nenhum histórico de saldo ainda.'), findsOneWidget);
  });
}
