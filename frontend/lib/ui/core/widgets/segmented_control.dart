import 'package:flutter/material.dart';

import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_spacing.dart';

/// One selectable option in an [AppSegmentedControl].
class AppSegment<T> {
  const AppSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// Pill-shaped tab group per `design.md`'s Component Patterns — mirrors the
/// mockup's mobile `.seg` (`web-mockups.html:36-38`) and web `.wseg`
/// (`web-mockups.html:84-86`) segmented controls: the group itself has no
/// background, only the active segment gets a filled pill. Used for
/// Saldos/Extrato and Gastos/Fluxo/Investimentos sub-navigation.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final segment in segments)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: _Segment<T>(
              segment: segment,
              active: segment.value == selected,
              onChanged: onChanged,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
      ],
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.active,
    required this.onChanged,
    required this.colorScheme,
    required this.textTheme,
  });

  final AppSegment<T> segment;
  final bool active;
  final ValueChanged<T> onChanged;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.buttonsPills),
      onTap: () => onChanged(segment.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active
              ? colorScheme.surfaceContainerHighest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.buttonsPills),
        ),
        child: Text(
          segment.label,
          style: textTheme.labelLarge?.copyWith(
            color: active
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
