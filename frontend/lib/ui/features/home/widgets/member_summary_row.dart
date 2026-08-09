import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Per-member spend summary row for the future Início screen — matches
/// `web-mockups.html:143-145` (mobile per-member list row) and `:373-375`
/// (web per-member table row). Built as a plain `Row` rather than a
/// `DataTable` (the repo has none today) so the exact same widget drops into
/// a `ListView` on mobile or a manually-laid-out table-like `Column` on web.
class MemberSummaryRow extends StatelessWidget {
  const MemberSummaryRow({
    super.key,
    required this.memberName,
    required this.memberColor,
    this.accountCount,
    required this.comparisonText,
    this.comparisonIsWarning = false,
    required this.amount,
    this.amountIsWarning = false,
  });

  final String memberName;
  final Color memberColor;

  /// Number of accounts for this member. `null` hides that cell — the
  /// mobile mockup omits it, the web table shows it.
  final int? accountCount;

  final String comparisonText;
  final bool comparisonIsWarning;

  /// Pre-formatted money string — this widget doesn't format currency,
  /// that's the caller's job (see `design.md`'s locale-aware formatting).
  final String amount;
  final bool amountIsWarning;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final warningColor = AppPalette.warningText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: memberColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 1),
          Expanded(child: Text(memberName, style: textTheme.bodyMedium)),
          if (accountCount != null) ...[
            SizedBox(
              width: 40,
              child: Text(
                '$accountCount',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              comparisonText,
              style: textTheme.bodySmall?.copyWith(
                color: comparisonIsWarning ? warningColor : null,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            amount,
            style: AppTypography.amountSmall.copyWith(
              color: amountIsWarning
                  ? warningColor
                  : Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
