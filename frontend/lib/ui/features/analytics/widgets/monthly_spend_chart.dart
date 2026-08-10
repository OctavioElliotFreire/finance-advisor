import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'monthly_spend_chart_data.dart';

/// Interim single-series stand-in for the Análises → Gastos monthly chart.
///
/// The mockup (`web-mockups.html:184-193` mobile, `:470-484` web) shows a
/// 3-segment per-member stacked bar per month, but that needs a backend
/// per-member monthly aggregation endpoint that doesn't exist yet (see
/// `design.md`'s Open Questions — the per-member breakdown is also still
/// unconfirmed as the intended meaning of those segments). Until that
/// endpoint lands, this renders the same `MonthlyCashFlow`-derived monthly
/// totals as a plain single-series `fl_chart` `BarChart`, ink-colored,
/// with the same axis/label conventions as `cash_flow_chart.dart`.
class MonthlySpendChart extends StatelessWidget {
  const MonthlySpendChart({super.key, required this.data});

  final MonthlySpendChartData data;

  @override
  Widget build(BuildContext context) {
    final points = data.points;
    if (points.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Nenhum dado de gastos ainda.')),
      );
    }

    final maxValue = points.fold<double>(
      0,
      (max, p) => p.total > max ? p.total : max,
    );
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final yInterval = maxY / 4;

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: yInterval <= 0 ? 1 : yInterval,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      points[index].monthLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: points[i].total,
                    color: AppPalette.ink,
                    width: 18,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
