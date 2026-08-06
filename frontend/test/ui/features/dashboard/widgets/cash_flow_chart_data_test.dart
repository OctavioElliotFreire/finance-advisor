import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/dashboard.dart';
import 'package:frontend/ui/features/dashboard/widgets/cash_flow_chart_data.dart';

void main() {
  group('CashFlowChartData.fromMonthlyCashFlow', () {
    test('maps each month to a labeled chart point', () {
      final data = CashFlowChartData.fromMonthlyCashFlow([
        const MonthlyCashFlow(month: '2026-06', income: 5000, expenses: 3200, net: 1800),
        const MonthlyCashFlow(month: '2026-07', income: 5100, expenses: 4000, net: 1100),
      ]);

      expect(data.isEmpty, isFalse);
      expect(data.points, hasLength(2));
      expect(data.points[0].monthLabel, 'Jun 2026');
      expect(data.points[0].income, 5000);
      expect(data.points[0].expenses, 3200);
      expect(data.points[1].monthLabel, 'Jul 2026');
    });

    test('handles an empty list without throwing', () {
      final data = CashFlowChartData.fromMonthlyCashFlow(const []);

      expect(data.isEmpty, isTrue);
      expect(data.points, isEmpty);
    });
  });
}
