import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_chart_colors.dart';
import '../../../core/widgets/chart_palette.dart';
import 'cash_flow_chart_data.dart';

class CashFlowChart extends StatelessWidget {
  const CashFlowChart({super.key, required this.data});

  final CashFlowChartData data;

  @override
  Widget build(BuildContext context) {
    final points = data.points;
    final maxValue = points
        .expand((p) => [p.income, p.expenses])
        .fold<double>(0, (max, value) => value > max ? value : max);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final yInterval = maxY / 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
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
                        toY: points[i].income,
                        color: AppChartColors.income(context),
                        width: 8,
                      ),
                      BarChartRodData(
                        toY: points[i].expenses,
                        color: AppChartColors.expenses(context),
                        width: 8,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            LegendSwatch(color: AppChartColors.income(context), label: 'Income'),
            const SizedBox(width: 16),
            LegendSwatch(color: AppChartColors.expenses(context), label: 'Expenses'),
          ],
        ),
      ],
    );
  }
}
