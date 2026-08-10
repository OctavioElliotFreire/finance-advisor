import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/ui/features/dashboard/widgets/cash_flow_chart_data.dart';
import 'package:frontend/ui/features/dashboard/widgets/combo_cash_flow_chart.dart';

void main() {
  testWidgets('renders a legend row with the default labels', (tester) async {
    const data = CashFlowChartData(
      points: [
        CashFlowChartPoint(monthLabel: 'Jun 2026', income: 5000, expenses: 3200),
        CashFlowChartPoint(monthLabel: 'Jul 2026', income: 5100, expenses: 4000),
      ],
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ComboCashFlowChart(data: data))));
    await tester.pumpAndSettle();

    expect(find.text('Entradas'), findsOneWidget);
    expect(find.text('Saídas'), findsOneWidget);
  });

  testWidgets('renders custom legend labels when given', (tester) async {
    const data = CashFlowChartData(
      points: [CashFlowChartPoint(monthLabel: 'Jun 2026', income: 5000, expenses: 3200)],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ComboCashFlowChart(data: data, inflowLabel: 'Receitas', outflowLabel: 'Despesas'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Receitas'), findsOneWidget);
    expect(find.text('Despesas'), findsOneWidget);
  });

  testWidgets('renders a fallback message when there is no data', (tester) async {
    const data = CashFlowChartData(points: []);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ComboCashFlowChart(data: data))));

    expect(find.text('Nenhum dado de fluxo de caixa ainda.'), findsOneWidget);
  });
}
