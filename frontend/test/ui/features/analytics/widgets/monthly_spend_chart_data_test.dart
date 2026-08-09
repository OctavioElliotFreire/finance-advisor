import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/dashboard.dart';
import 'package:frontend/ui/features/analytics/widgets/monthly_spend_chart_data.dart';

void main() {
  test('maps each month to its expenses total', () {
    final data = MonthlySpendChartData.fromMonthlyCashFlow(const [
      MonthlyCashFlow(month: '2026-06', income: 5000, expenses: 3200, net: 1800),
      MonthlyCashFlow(month: '2026-07', income: 5100, expenses: 4000, net: 1100),
    ]);

    expect(data.isEmpty, isFalse);
    expect(data.points, hasLength(2));
    expect(data.points[0].total, 3200);
    expect(data.points[1].total, 4000);
  });

  test('isEmpty is true for an empty series', () {
    final data = MonthlySpendChartData.fromMonthlyCashFlow(const []);

    expect(data.isEmpty, isTrue);
  });
}
