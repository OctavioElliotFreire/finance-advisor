import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/extended_finance.dart';
import 'package:frontend/ui/features/finances/widgets/balance_history_chart_data.dart';

void main() {
  group('BalanceHistoryChartData.fromBalancePoints', () {
    test('maps each point to a labeled chart point', () {
      final data = BalanceHistoryChartData.fromBalancePoints([
        BalancePoint(snapshotDate: DateTime(2026, 6, 1), totalBalance: 1000),
        BalancePoint(snapshotDate: DateTime(2026, 7, 1), totalBalance: 1200),
      ]);

      expect(data.isEmpty, isFalse);
      expect(data.points, hasLength(2));
      expect(data.points[0].balance, 1000);
      expect(data.points[1].balance, 1200);
    });

    test('handles a single point without throwing', () {
      final data = BalanceHistoryChartData.fromBalancePoints([
        BalancePoint(snapshotDate: DateTime(2026, 6, 1), totalBalance: 1000),
      ]);

      expect(data.points, hasLength(1));
    });

    test('handles an empty list without throwing', () {
      final data = BalanceHistoryChartData.fromBalancePoints(const []);

      expect(data.isEmpty, isTrue);
      expect(data.points, isEmpty);
    });
  });
}
