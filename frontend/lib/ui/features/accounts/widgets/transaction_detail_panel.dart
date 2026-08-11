import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/dashboard.dart';
import '../../../../data/repositories/dashboard_repository.dart';
import '../../../core/formatting/money.dart';
import '../../../core/widgets/category_pill.dart';
import '../../../core/widgets/member_dot.dart';

/// Mobile entry point for the drill-down panel — a scroll-controlled bottom
/// sheet, same mechanics as `period_pill.dart`'s `_openSheet` (the only
/// other bottom-sheet precedent in this app).
Future<void> showTransactionDetailSheet(
  BuildContext context, {
  required TransactionSummary transaction,
  required String? accountName,
  required Color memberColor,
  required String memberLabel,
  required List<String> knownCategories,
  required DashboardRepository dashboardRepository,
  required String householdId,
  required ValueChanged<TransactionSummary> onUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: SafeArea(
        child: TransactionDetailPanel(
          transaction: transaction,
          accountName: accountName,
          memberColor: memberColor,
          memberLabel: memberLabel,
          knownCategories: knownCategories,
          dashboardRepository: dashboardRepository,
          householdId: householdId,
          onUpdated: onUpdated,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    ),
  );
}

/// Shared content for both the mobile bottom sheet and the web side panel —
/// full merchant name (`description`, the only field this app has; there's
/// no separate "raw bank descriptor" anywhere in the sync pipeline), account,
/// member, amount, plus the three drill-down actions `design.md:344` names:
/// recategorize, split, flag.
class TransactionDetailPanel extends StatefulWidget {
  const TransactionDetailPanel({
    super.key,
    required this.transaction,
    required this.accountName,
    required this.memberColor,
    required this.memberLabel,
    required this.knownCategories,
    required this.dashboardRepository,
    required this.householdId,
    required this.onUpdated,
    this.onClose,
  });

  final TransactionSummary transaction;
  final String? accountName;
  final Color memberColor;
  final String memberLabel;
  final List<String> knownCategories;
  final DashboardRepository dashboardRepository;
  final String householdId;
  final ValueChanged<TransactionSummary> onUpdated;
  final VoidCallback? onClose;

  @override
  State<TransactionDetailPanel> createState() => _TransactionDetailPanelState();
}

class _TransactionDetailPanelState extends State<TransactionDetailPanel> {
  late TransactionSummary _transaction = widget.transaction;
  bool _isEditingCategory = false;
  bool _isEditingSplits = false;
  bool _isBusy = false;
  late List<_SplitDraft> _splitDrafts = _draftsFrom(_transaction.splits);

  static List<_SplitDraft> _draftsFrom(List<TransactionSplitItem> splits) {
    return splits
        .map(
          (s) => _SplitDraft(
            category: s.category,
            amount: s.amount.abs().toStringAsFixed(2),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final draft in _splitDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _applyUpdate(TransactionSummary updated) {
    setState(() => _transaction = updated);
    widget.onUpdated(updated);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _setCategory(String? category) async {
    await _run(() async {
      final updated = await widget.dashboardRepository
          .updateTransactionCategory(
            widget.householdId,
            _transaction.id,
            category,
          );
      _applyUpdate(updated);
      setState(() => _isEditingCategory = false);
    });
  }

  double get _splitRemainder {
    final parentAbs = _transaction.amount.abs();
    final draftedAbs = _splitDrafts.fold<double>(
      0,
      (sum, d) => sum + (double.tryParse(d.amount.replaceAll(',', '.')) ?? 0),
    );
    return parentAbs - draftedAbs;
  }

  Future<void> _saveSplits() async {
    final isNegative = _transaction.amount < 0;
    final items = _splitDrafts.where((d) => d.category.trim().isNotEmpty).map((
      d,
    ) {
      final magnitude = double.tryParse(d.amount.replaceAll(',', '.')) ?? 0;
      return TransactionSplitItem(
        category: d.category.trim(),
        amount: isNegative ? -magnitude : magnitude,
      );
    }).toList();

    await _run(() async {
      final updated = await widget.dashboardRepository.updateTransactionSplits(
        widget.householdId,
        _transaction.id,
        items,
      );
      _applyUpdate(updated);
      setState(() {
        _isEditingSplits = false;
        _splitDrafts = _draftsFrom(updated.splits);
      });
    });
  }

  Future<void> _clearSplits() async {
    await _run(() async {
      final updated = await widget.dashboardRepository.updateTransactionSplits(
        widget.householdId,
        _transaction.id,
        const [],
      );
      _applyUpdate(updated);
      setState(() {
        _isEditingSplits = false;
        _splitDrafts = [];
      });
    });
  }

  Future<void> _toggleFlag() async {
    await _run(() async {
      if (_transaction.flagId == null) {
        final flag = await widget.dashboardRepository.flagTransaction(
          widget.householdId,
          _transaction.id,
        );
        _applyUpdate(_transaction.copyWith(isFlagged: true, flagId: flag.id));
      } else {
        await widget.dashboardRepository.updateAnomalyStatus(
          widget.householdId,
          _transaction.flagId!,
          'dismissed',
        );
        _applyUpdate(
          _transaction.copyWith(isFlagged: false, clearFlagId: true),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final txn = _transaction;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  txn.description ?? 'Movimentação',
                  style: textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
                tooltip: 'Fechar',
              ),
            ],
          ),
          Text(
            '${formatDayMonth(txn.transactionDate)} · ${formatMoney(txn.amount, txn.currencyCode)}',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(label: 'Conta', value: widget.accountName ?? 'Conta'),
          _InfoRow(
            label: 'Membro',
            value: widget.memberLabel,
            leading: MemberDot(color: widget.memberColor),
          ),
          const Divider(height: AppSpacing.xl),

          Text('Categoria', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (!_isEditingCategory)
            Row(
              children: [
                Expanded(
                  child: txn.category == null
                      ? Text('Sem categoria', style: textTheme.bodyMedium)
                      : CategoryPill(label: txn.category!),
                ),
                TextButton(
                  onPressed: _isBusy
                      ? null
                      : () => setState(() => _isEditingCategory = true),
                  child: const Text('Alterar categoria'),
                ),
              ],
            )
          else
            _CategoryPicker(
              knownCategories: widget.knownCategories,
              onSelected: _isBusy ? null : _setCategory,
              onCancel: () => setState(() => _isEditingCategory = false),
            ),
          const Divider(height: AppSpacing.xl),

          Text('Dividir movimentação', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (!_isEditingSplits && txn.splits.isEmpty)
            Row(
              children: [
                const Expanded(child: Text('Não dividida')),
                TextButton(
                  onPressed: _isBusy
                      ? null
                      : () => setState(() => _isEditingSplits = true),
                  child: const Text('Dividir'),
                ),
              ],
            )
          else if (!_isEditingSplits)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final split in txn.splits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: CategoryPill(label: split.category)),
                        Text(formatMoney(split.amount, txn.currencyCode)),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () => setState(() => _isEditingSplits = true),
                      child: const Text('Editar divisão'),
                    ),
                    TextButton(
                      onPressed: _isBusy ? null : _clearSplits,
                      child: const Text('Remover divisão'),
                    ),
                  ],
                ),
              ],
            )
          else
            _SplitEditor(
              drafts: _splitDrafts,
              remainder: _splitRemainder,
              currencyCode: txn.currencyCode,
              onChanged: () => setState(() {}),
              onAdd: () => setState(
                () => _splitDrafts.add(_SplitDraft(category: '', amount: '')),
              ),
              onRemove: (index) => setState(() {
                _splitDrafts[index].dispose();
                _splitDrafts.removeAt(index);
              }),
              onCancel: () => setState(() {
                _isEditingSplits = false;
                _splitDrafts = _draftsFrom(txn.splits);
              }),
              onSave:
                  (_splitRemainder.abs() < 0.01 &&
                      _splitDrafts.isNotEmpty &&
                      !_isBusy)
                  ? _saveSplits
                  : null,
            ),
          const Divider(height: AppSpacing.xl),

          OutlinedButton.icon(
            onPressed: _isBusy ? null : _toggleFlag,
            icon: Icon(txn.flagId == null ? Icons.flag_outlined : Icons.flag),
            label: Text(
              txn.flagId == null ? 'Sinalizar' : 'Remover sinalização',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.leading});

  final String label;
  final String value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
          const Spacer(),
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(value),
        ],
      ),
    );
  }
}

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({
    required this.knownCategories,
    required this.onSelected,
    required this.onCancel,
  });

  final List<String> knownCategories;
  final ValueChanged<String?>? onSelected;
  final VoidCallback onCancel;

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final category in widget.knownCategories)
              ActionChip(
                label: Text(category),
                onPressed: widget.onSelected == null
                    ? null
                    : () => widget.onSelected!(category),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customController,
                decoration: const InputDecoration(hintText: 'Outra categoria'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: widget.onSelected == null
                  ? null
                  : () {
                      final value = _customController.text.trim();
                      if (value.isNotEmpty) widget.onSelected!(value);
                    },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onCancel,
            ),
          ],
        ),
      ],
    );
  }
}

class _SplitDraft {
  _SplitDraft({required String category, required String amount})
    : categoryController = TextEditingController(text: category),
      amountController = TextEditingController(text: amount);

  final TextEditingController categoryController;
  final TextEditingController amountController;

  String get category => categoryController.text;
  String get amount => amountController.text;

  void dispose() {
    categoryController.dispose();
    amountController.dispose();
  }
}

class _SplitEditor extends StatelessWidget {
  const _SplitEditor({
    required this.drafts,
    required this.remainder,
    required this.currencyCode,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onCancel,
    required this.onSave,
  });

  final List<_SplitDraft> drafts;
  final double remainder;
  final String currencyCode;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onCancel;
  final Future<void> Function()? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < drafts.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: drafts[i].categoryController,
                    decoration: const InputDecoration(hintText: 'Categoria'),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: drafts[i].amountController,
                    decoration: const InputDecoration(hintText: 'Valor'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => onRemove(i),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar divisão'),
        ),
        Text(
          remainder.abs() < 0.01
              ? 'Total confere'
              : 'Restante: ${formatMoney(remainder, currencyCode)}',
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            TextButton(onPressed: onCancel, child: const Text('Cancelar')),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(onPressed: onSave, child: const Text('Salvar')),
          ],
        ),
      ],
    );
  }
}
