import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_chart_colors.dart';
import '../../../core/formatting/money.dart';
import 'category_breakdown_chart_data.dart';

class CategoryBreakdownChart extends StatelessWidget {
  const CategoryBreakdownChart({super.key, required this.data});

  final CategoryBreakdownChartData data;

  @override
  Widget build(BuildContext context) {
    final slices = data.slices;
    if (slices.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('No categorized spending yet.')),
      );
    }

    final total = slices.fold<double>(0, (sum, s) => sum + s.total);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 32,
              sections: [
                for (final slice in slices)
                  PieChartSectionData(
                    value: slice.total <= 0 ? 0.0001 : slice.total,
                    color: AppChartColors.categoricalColorFor(context, slice.label),
                    title: '',
                    radius: 48,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _CategoryLegend(slices: slices, total: total)),
      ],
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  const _CategoryLegend({required this.slices, required this.total});

  final List<CategoryBreakdownSlice> slices;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  color: AppChartColors.categoricalColorFor(context, slice.label),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(slice.label)),
                Text(
                  formatMoney(slice.total, 'BRL'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Text(
                  total <= 0
                      ? '0%'
                      : '${(slice.total / total * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
