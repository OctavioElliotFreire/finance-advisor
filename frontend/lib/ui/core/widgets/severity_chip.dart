import 'package:flutter/material.dart';

import 'status_chip.dart';

/// Anomaly severity chip, built on [StatusChip]'s tone system so severity
/// shares the same colorblind-safe container+text signaling as sync/connection
/// status rather than its own bespoke color switch.
class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.severity});

  final String severity;

  static (StatusTone, String) _toneAndLabel(String severity) {
    return switch (severity) {
      'high' => (StatusTone.negative, 'Alta'),
      'medium' => (StatusTone.warning, 'Média'),
      'low' => (StatusTone.neutral, 'Baixa'),
      _ => (StatusTone.neutral, severity),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (tone, label) = _toneAndLabel(severity);
    return StatusChip(label: label, tone: tone);
  }
}
