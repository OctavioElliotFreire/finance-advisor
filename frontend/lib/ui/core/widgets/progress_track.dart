import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// One colored segment of a [ProgressTrack], sized as a fraction (0-1) of
/// the track's total width.
class ProgressSegment {
  const ProgressSegment({required this.fraction, required this.color});

  final double fraction;
  final Color color;
}

/// Thin rounded progress bar per `design.md`'s Component Patterns — mirrors
/// the mockup's `.trk`/`.wtrk`/`.track` bars (`web-mockups.html:44,52,76`).
/// Renders zero, one, or two ordered segments over a rounded background
/// track. The two-segment case is the realized-vs-committed budget bar; the
/// one-segment case is the credit-limit-used bar.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.segments,
    this.height = 6,
    this.trackColor = AppPalette.surfaceFill,
  });

  final List<ProgressSegment> segments;
  final double height;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    // Flex factors must be > 0, so zero-fraction segments are dropped and
    // the remainder spacer is only added when strictly positive.
    final remainder = (1 - _totalFraction).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: trackColor,
        child: Row(
          children: [
            for (final segment in segments)
              if (segment.fraction > 0)
                Expanded(
                  flex: (segment.fraction.clamp(0.0, 1.0) * 1000).round().clamp(
                    1,
                    1000,
                  ),
                  child: Container(height: height, color: segment.color),
                ),
            if (remainder > 0)
              Expanded(
                flex: (remainder * 1000).round().clamp(1, 1000),
                child: const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }

  double get _totalFraction => segments.fold<double>(
    0,
    (sum, segment) => sum + segment.fraction.clamp(0.0, 1.0),
  );
}
