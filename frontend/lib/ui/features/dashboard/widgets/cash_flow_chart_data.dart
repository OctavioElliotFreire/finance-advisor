import '../../../../data/models/dashboard.dart';
import '../../../core/formatting/money.dart';

class CashFlowChartPoint {
  const CashFlowChartPoint({
    required this.monthLabel,
    required this.income,
    required this.expenses,
  });

  final String monthLabel;
  final double income;
  final double expenses;
}

class CashFlowChartData {
  const CashFlowChartData({required this.points});

  factory CashFlowChartData.fromMonthlyCashFlow(
    List<MonthlyCashFlow> monthlyCashFlow,
  ) {
    return CashFlowChartData(
      points: [
        for (final month in monthlyCashFlow)
          CashFlowChartPoint(
            monthLabel: formatMonth(month.month),
            income: month.income,
            expenses: month.expenses,
          ),
      ],
    );
  }

  final List<CashFlowChartPoint> points;

  bool get isEmpty => points.isEmpty;
}
