import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_chart_colors.dart';
import '../../../core/formatting/money.dart';
import '../../../core/widgets/chart_palette.dart';
import 'monthly_spend_chart_data.dart';

/// Análises → Gastos monthly chart, per `design.md`'s "Monthly spend by
/// member" spec and its density rulebook — mode is decided entirely by
/// [MonthlySpendChartData.fromMemberSpend] (unstacked household bar when
/// every member is in scope, a real per-member stacked bar for an explicit
/// 2-4-member selection, or a plain ranked list — refusing to stack — for
/// 5+). This widget just renders whichever mode it's handed.
class MonthlySpendChart extends StatelessWidget {
  const MonthlySpendChart({super.key, required this.data});

  final MonthlySpendChartData data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Nenhum dado de gastos ainda.')),
      );
    }

    if (data.mode == MonthlySpendChartMode.rankedList) {
      return _RankedSpendList(data: data);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlySpendBarChart(data: data),
        if (data.mode == MonthlySpendChartMode.stacked && data.legend.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final entry in data.legend) LegendSwatch(color: entry.color, label: entry.label),
            ],
          ),
        ],
      ],
    );
  }
}

class _MonthlySpendBarChart extends StatelessWidget {
  const _MonthlySpendBarChart({required this.data});

  final MonthlySpendChartData data;

  @override
  Widget build(BuildContext context) {
    final points = data.points;
    final maxValue = points.fold<double>(0, (max, p) => p.total > max ? p.total : max);
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final yInterval = maxY / 4;
    final stacked = data.mode == MonthlySpendChartMode.stacked;

    return SizedBox(
      height: monthlySpendChartPlotHeightPx + 40,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                    child: Text(points[index].monthLabel, style: Theme.of(context).textTheme.bodySmall),
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
                  stacked ? _stackedRod(points[i]) : BarChartRodData(toY: points[i].total, color: AppChartColors.expenses(context), width: 18),
                ],
              ),
          ],
        ),
      ),
    );
  }

  BarChartRodData _stackedRod(MonthlySpendChartPoint point) {
    var cumulative = 0.0;
    final stackItems = <BarChartRodStackItem>[];
    for (final segment in point.segments) {
      final from = cumulative;
      cumulative += segment.value;
      stackItems.add(BarChartRodStackItem(from, cumulative, segment.color));
    }
    return BarChartRodData(toY: cumulative, rodStackItems: stackItems, width: 18);
  }
}

/// The 5+-member fallback: no chart at all, per the density rulebook's
/// "refuse to stack — show totals plus a ranked list instead."
class _RankedSpendList extends StatelessWidget {
  const _RankedSpendList({required this.data});

  final MonthlySpendChartData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Muitas pessoas selecionadas para um gráfico por pessoa — mostrando o total de cada uma.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final entry in data.rankedTotals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: LegendSwatch(color: entry.color, label: entry.label)),
                Text(formatMoney(entry.value, 'BRL'), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}
