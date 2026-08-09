import '../../../../data/models/dashboard.dart';
import '../../../core/formatting/money.dart';

class MonthlySpendChartPoint {
  const MonthlySpendChartPoint({required this.monthLabel, required this.total});

  final String monthLabel;
  final double total;
}

class MonthlySpendChartData {
  const MonthlySpendChartData({required this.points});

  factory MonthlySpendChartData.fromMonthlyCashFlow(
    List<MonthlyCashFlow> monthlyCashFlow,
  ) {
    return MonthlySpendChartData(
      points: [
        for (final month in monthlyCashFlow)
          MonthlySpendChartPoint(
            monthLabel: formatMonth(month.month),
            total: month.expenses,
          ),
      ],
    );
  }

  final List<MonthlySpendChartPoint> points;

  bool get isEmpty => points.isEmpty;
}
