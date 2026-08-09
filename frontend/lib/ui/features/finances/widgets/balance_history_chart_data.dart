import '../../../../data/models/extended_finance.dart';
import '../../../core/formatting/money.dart';

class BalanceHistoryChartPoint {
  const BalanceHistoryChartPoint({
    required this.dateLabel,
    required this.balance,
  });

  final String dateLabel;
  final double balance;
}

class BalanceHistoryChartData {
  const BalanceHistoryChartData({required this.points});

  factory BalanceHistoryChartData.fromBalancePoints(
    List<BalancePoint> balancePoints,
  ) {
    return BalanceHistoryChartData(
      points: [
        for (final point in balancePoints)
          BalanceHistoryChartPoint(
            dateLabel: formatShortDate(point.snapshotDate),
            balance: point.totalBalance,
          ),
      ],
    );
  }

  final List<BalanceHistoryChartPoint> points;

  bool get isEmpty => points.isEmpty;
}
