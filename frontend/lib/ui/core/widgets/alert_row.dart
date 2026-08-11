import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_spacing.dart';
import 'status_chip.dart';

/// Heavier-weight sibling to [StatusChip] for a dedicated "needs attention"
/// callout, rather than an inline tag — matches the mockup's `.al` alert row
/// (`web-mockups.html:81`, used at `:357-364`): leading icon, title, optional
/// muted subtitle, full-row tinted background when the alert is in a state,
/// plain-bordered card when merely informational.
class AppAlertRow extends StatelessWidget {
  const AppAlertRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = StatusTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;
    final textTheme = Theme.of(context).textTheme;

    final (background, foreground, border) = switch (tone) {
      StatusTone.warning => (
        semanticColors.warningContainer,
        semanticColors.warning,
        Colors.transparent,
      ),
      StatusTone.negative => (
        colorScheme.errorContainer,
        colorScheme.error,
        Colors.transparent,
      ),
      StatusTone.info => (
        colorScheme.tertiaryContainer,
        colorScheme.tertiary,
        Colors.transparent,
      ),
      StatusTone.neutral => (
        colorScheme.surface,
        colorScheme.onSurfaceVariant,
        colorScheme.outline,
      ),
    };

    final titleColor = tone == StatusTone.neutral
        ? colorScheme.onSurface
        : foreground;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.innerCard),
        border: border == Colors.transparent
            ? null
            : Border.all(color: border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(color: titleColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
