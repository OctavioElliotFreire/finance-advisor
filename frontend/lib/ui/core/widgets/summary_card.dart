import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Dashboard stat-tile pattern: label above, big value below, optional
/// trailing chip. Extracted from `_OverviewSection` so a future second stat
/// tile doesn't need a second bespoke card.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.child,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: textTheme.titleMedium),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.amountLarge.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            if (child != null) ...[const SizedBox(height: AppSpacing.lg), child!],
          ],
        ),
      ),
    );
  }
}
