import 'package:flutter/material.dart';

import '../../../core/theme/app_shape.dart';

/// Neutral category tag for Contas · Extrato's six-column web table —
/// `surface-fill` background, `ink-secondary` text, per `design.md`'s
/// Table conventions: category is never colored, color is reserved for
/// member identity.
class CategoryPill extends StatelessWidget {
  const CategoryPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
