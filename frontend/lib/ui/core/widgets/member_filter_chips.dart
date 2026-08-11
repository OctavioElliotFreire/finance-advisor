import 'package:flutter/material.dart';

import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_spacing.dart';

/// One toggleable member option in [MemberFilterChips].
class MemberFilterOption {
  const MemberFilterOption({
    required this.id,
    required this.label,
    required this.color,
    required this.selected,
  });

  final String id;
  final String label;
  final Color color;
  final bool selected;
}

/// Household-member scoping control per `design.md` — a first-class,
/// always-visible filter (not buried in settings) sitting at the top of
/// every scoped screen (Início/Contas/Análises), persisting selection
/// across sub-tabs. Mirrors the mockup's `.chip`/`.chip.off` pills
/// (`web-mockups.html:39-40,156-159`): checkbox-style leading icon, a small
/// member-color dot, and the member's name.
class MemberFilterChips extends StatelessWidget {
  const MemberFilterChips({
    super.key,
    required this.members,
    required this.onToggle,
  });

  final List<MemberFilterOption> members;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final member in members)
          _MemberChip(member: member, onTap: () => onToggle(member.id)),
      ],
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.member, required this.onTap});

  final MemberFilterOption member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borderColor = member.selected
        ? colorScheme.outlineVariant
        : colorScheme.outline;
    final textColor = member.selected ? null : colorScheme.tertiary;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm + 2,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              member.selected
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank,
              size: 16,
              color: member.selected ? member.color : colorScheme.tertiary,
            ),
            const SizedBox(width: 5),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: member.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              member.label,
              style: textTheme.labelMedium?.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
