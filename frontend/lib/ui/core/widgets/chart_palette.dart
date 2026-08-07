import 'package:flutter/material.dart';

/// Shared chart-legend swatch (color square + label), replacing two
/// near-identical private `_LegendSwatch` copies in the cash-flow and
/// category-breakdown charts. Colors themselves live in
/// `core/theme/app_chart_colors.dart`'s [AppChartColors] — this widget just
/// renders whatever color/label a chart passes in.
class LegendSwatch extends StatelessWidget {
  const LegendSwatch({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
