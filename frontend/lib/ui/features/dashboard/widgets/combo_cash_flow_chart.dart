import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_chart_colors.dart';
import '../../../core/widgets/chart_palette.dart';
import 'cash_flow_chart_data.dart';

/// Combo cash-flow chart per `design.md`'s Chart Style Guide: muted bars for
/// inflows (income) behind a dark connected line-with-dots for outflows
/// (expenses), sharing one X-axis/`maxY` scale — mirrors the mockup's
/// `web-mockups.html:220-236` SVG. Reuses the existing
/// [CashFlowChartData]/[CashFlowChartPoint] shape (no new data file); this
/// widget only changes how the same two series are rendered (combo instead
/// of grouped bars — see `cash_flow_chart.dart` for the superseded version).
class ComboCashFlowChart extends StatelessWidget {
  const ComboCashFlowChart({
    super.key,
    required this.data,
    this.inflowLabel = 'Entradas',
    this.outflowLabel = 'Saídas',
  });

  final CashFlowChartData data;
  final String inflowLabel;
  final String outflowLabel;

  @override
  Widget build(BuildContext context) {
    final points = data.points;
    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Nenhum dado de fluxo de caixa ainda.')),
      );
    }

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
          child: Stack(
            children: [
              BarChart(
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
                            width: 18,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Overlaid on the same maxY scale (both LineChart and BarChart
              // above stretch to fill this Stack, so their axes align) so
              // the outflow line reads against the inflow bars behind it.
              LineChart(
                LineChartData(
                  maxY: maxY,
                  minY: 0,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  titlesData: const FlTitlesData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].expenses),
                      ],
                      isCurved: false,
                      color: AppChartColors.expenses(context),
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            LegendSwatch(color: AppChartColors.income(context), label: inflowLabel),
            const SizedBox(width: 16),
            LegendSwatch(color: AppChartColors.expenses(context), label: outflowLabel),
          ],
        ),
      ],
    );
  }
}
