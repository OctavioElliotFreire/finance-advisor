import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../core/widgets/status_chip.dart';

/// Plain list row showing one connection/account's health for the future
/// Família screen — matches `web-mockups.html:160-168` (mobile) and
/// `:269-270,278-279,288-290` (per-member connection lines) row style. This
/// is lighter weight than [AppAlertRow] — a single row in a group, not a
/// dedicated callout — so the group's contextual CTA button (renew/reconnect)
/// is left to the caller to place below the row group.
class ConnectionHealthRow extends StatelessWidget {
  const ConnectionHealthRow({
    super.key,
    required this.label,
    required this.statusText,
    this.tone = StatusTone.neutral,
    this.dotColor,
  });

  final String label;
  final String statusText;
  final StatusTone tone;

  /// Member accent color when healthy; callers override to the
  /// warning/danger color when [tone] isn't neutral.
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final semanticColors = context.semanticColors;
    final colorScheme = Theme.of(context).colorScheme;

    final statusColor = switch (tone) {
      StatusTone.warning => semanticColors.warning,
      StatusTone.negative => colorScheme.error,
      StatusTone.info => colorScheme.tertiary,
      StatusTone.neutral => colorScheme.onSurfaceVariant,
    };
    final labelColor = tone == StatusTone.neutral ? null : statusColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor ?? statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: labelColor),
            ),
          ),
          Text(
            statusText,
            style: textTheme.bodySmall?.copyWith(color: statusColor),
          ),
        ],
      ),
    );
  }
}
