import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_shape.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/scope_controller.dart';

const _presetLabels = <PeriodPreset, String>{
  PeriodPreset.thisMonth: 'Este mês',
  PeriodPreset.lastMonth: 'Mês passado',
  PeriodPreset.last3Months: 'Últimos 3 meses',
  PeriodPreset.thisYear: 'Este ano',
  PeriodPreset.last12Months: 'Últimos 12 meses',
  PeriodPreset.custom: 'Período personalizado',
};

String _shortDate(DateTime date) => DateFormat('dd/MM', 'pt_BR').format(date);

/// Period picker per `design.md`'s Global Scope section (§4): a center pill
/// flanked by ‹ › step arrows, tapping the pill opens the preset/custom-range
/// sheet, and a "Comparar com período anterior" toggle inside that sheet.
class PeriodPill extends StatelessWidget {
  const PeriodPill({super.key, required this.controller});

  final ScopeController controller;

  String _label() {
    final range = controller.resolveRange();
    final atNaturalAnchor = _isAtNaturalAnchor();
    if (atNaturalAnchor) return _presetLabels[controller.preset]!;
    return '${_shortDate(range.start)} – ${_shortDate(range.end)}';
  }

  bool _isAtNaturalAnchor() {
    final natural = ScopeController(householdId: controller.householdId);
    natural.setPreset(controller.preset);
    return controller.resolveRange() == natural.resolveRange();
  }

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PeriodSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: controller.stepBack,
          tooltip: 'Período anterior',
        ),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.buttonsPills),
          onTap: () => _openSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.buttonsPills),
            ),
            child: Text(_label(), style: Theme.of(context).textTheme.labelLarge),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: controller.stepForward,
          tooltip: 'Próximo período',
        ),
      ],
    );
  }
}

class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({required this.controller});

  final ScopeController controller;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final preset in PeriodPreset.values.where((p) => p != PeriodPreset.custom))
              RadioListTile<PeriodPreset>(
                value: preset,
                groupValue: controller.preset,
                title: Text(_presetLabels[preset]!),
                onChanged: (value) {
                  controller.setPreset(value!);
                  setState(() {});
                },
              ),
            ListTile(
              leading: Icon(
                controller.preset == PeriodPreset.custom
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: controller.preset == PeriodPreset.custom
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: const Text('Período personalizado'),
              onTap: () async {
                final now = DateTime.now();
                // No `locale:` override here — without `flutter_localizations`
                // (deliberately not a dependency, per design.md's "no l10n
                // framework" decision) the picker's own chrome (month names,
                // OK/Cancel) stays in English, the same known trade-off as
                // TextField's built-in character counter.
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 5),
                  lastDate: DateTime(now.year + 1),
                );
                if (picked != null) {
                  controller.setCustomRange(picked.start, picked.end);
                  setState(() {});
                }
              },
            ),
            const Divider(height: AppSpacing.lg),
            SwitchListTile(
              value: controller.comparePrevious,
              title: const Text('Comparar com período anterior'),
              onChanged: (value) {
                controller.setComparePrevious(value);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
