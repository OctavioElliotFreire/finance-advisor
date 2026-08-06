import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'balance_history_chart_data.dart';

const _lineColor = Colors.blue;

class BalanceHistoryChart extends StatelessWidget {
  const BalanceHistoryChart({super.key, required this.data});

  final BalanceHistoryChartData data;

  @override
  Widget build(BuildContext context) {
    final points = data.points;

    if (points.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No balance history yet.')),
      );
    }

    final balances = points.map((p) => p.balance).toList();
    final minBalance = balances.reduce((a, b) => a < b ? a : b);
    final maxBalance = balances.reduce((a, b) => a > b ? a : b);
    final range = maxBalance - minBalance;
    final padding = range > 0 ? range * 0.15 : (maxBalance.abs() * 0.1).clamp(1.0, double.infinity);
    final maxX = points.length <= 1 ? 1.0 : (points.length - 1).toDouble();
    final yInterval = ((maxBalance + padding) - (minBalance - padding)) / 4;
    final labelStep = (points.length / 5).ceil().clamp(1, points.length);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minBalance - padding,
          maxY: maxBalance + padding,
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
                reservedSize: 56,
                interval: yInterval <= 0 ? 1 : yInterval,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 ||
                      index >= points.length ||
                      index % labelStep != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      points[index].dateLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].balance),
              ],
              isCurved: false,
              color: _lineColor,
              barWidth: 2,
              dotData: FlDotData(show: points.length == 1),
            ),
          ],
        ),
      ),
    );
  }
}
