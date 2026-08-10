import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Semantic tone for a status/severity signal. Maps onto [AppSemanticColors]
/// (warning) or the base [ColorScheme] (negative -> error, info -> tertiary)
/// rather than adding more hues — see PLAN.md's design-system note.
///
/// There is deliberately no `success` tone — per `design.md`'s handoff-driven
/// correction, there is no positive/success color anywhere in this design.
/// A "this is fine" status is [neutral] (plain ink), not colored green.
enum StatusTone { neutral, info, warning, negative }

/// Colorblind-safe status chip: container-color background + on-container
/// text, with a small color dot as secondary reinforcement (not the only
/// signal). Unifies what used to be three separate ad hoc switch statements
/// (dashboard sync status, connections status, anomaly severity).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  /// Maps a [SyncJob.status] value (`null` before any sync) to a chip.
  static StatusChip syncStatus(String? status) {
    if (status == null) {
      return const StatusChip(
        label: 'Nunca sincronizado',
        tone: StatusTone.neutral,
      );
    }
    final (tone, label) = switch (status) {
      'completed' => (StatusTone.neutral, 'Sincronizado'),
      'partially_completed' => (StatusTone.warning, 'Sincronizado parcialmente'),
      'failed' => (StatusTone.negative, 'Falha na sincronização'),
      'running' => (StatusTone.info, 'Sincronizando…'),
      'queued' => (StatusTone.info, 'Na fila'),
      _ => (StatusTone.neutral, status),
    };
    return StatusChip(label: label, tone: tone);
  }

  /// Maps a Pluggy `PluggyConnection.status` value — Pluggy's own item
  /// status (`UPDATED`/`UPDATING`/`LOGIN_ERROR`/`OUTDATED`/
  /// `WAITING_USER_INPUT`/`ERROR`) passed through verbatim by the backend
  /// sync worker, or this app's own `"pending"` default before the first
  /// sync — to a chip. Matched case-insensitively since Pluggy's casing is
  /// external and not guaranteed.
  static StatusChip connectionStatus(String status) {
    final (tone, label) = switch (status.toUpperCase()) {
      'PENDING' => (StatusTone.neutral, 'Aguardando primeira sincronização'),
      'UPDATED' => (StatusTone.neutral, 'Ativo'),
      'UPDATING' => (StatusTone.info, 'Atualizando…'),
      'OUTDATED' => (StatusTone.warning, 'Desatualizado'),
      'WAITING_USER_INPUT' => (StatusTone.warning, 'Requer atenção'),
      'LOGIN_ERROR' => (StatusTone.negative, 'Erro de login'),
      'ERROR' => (StatusTone.negative, 'Erro'),
      _ => (StatusTone.neutral, status),
    };
    return StatusChip(label: label, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = context.semanticColors;

    final (background, foreground, dot) = switch (tone) {
      StatusTone.neutral => (
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
        colorScheme.onSurfaceVariant,
      ),
      StatusTone.info => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        colorScheme.tertiary,
      ),
      StatusTone.warning => (
        semanticColors.warningContainer,
        semanticColors.onWarningContainer,
        semanticColors.warning,
      ),
      StatusTone.negative => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        colorScheme.error,
      ),
    };

    return Chip(
      backgroundColor: background,
      side: BorderSide.none,
      avatar: CircleAvatar(backgroundColor: dot, radius: 6),
      label: Text(label, style: TextStyle(color: foreground)),
    );
  }
}
