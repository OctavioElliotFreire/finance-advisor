import 'package:flutter/material.dart';

import '../../../../data/models/anomaly.dart';
import '../../../../data/repositories/anomaly_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/severity_chip.dart';
import '../view_models/anomalies_view_model.dart';

const _statusFilters = <String?, String>{
  null: 'Todas',
  'open': 'Abertas',
  'confirmed': 'Confirmadas',
  'dismissed': 'Dispensadas',
};

String _statusLabel(String status) {
  return switch (status) {
    'open' => 'aberta',
    'confirmed' => 'confirmada',
    'dismissed' => 'dispensada',
    _ => status,
  };
}

class AnomaliesView extends StatefulWidget {
  const AnomaliesView({
    super.key,
    required this.anomalyRepository,
    required this.householdId,
    required this.householdName,
  });

  final AnomalyRepository anomalyRepository;
  final String householdId;
  final String householdName;

  @override
  State<AnomaliesView> createState() => _AnomaliesViewState();
}

class _AnomaliesViewState extends State<AnomaliesView> {
  late final _viewModel = AnomaliesViewModel(
    anomalyRepository: widget.anomalyRepository,
    householdId: widget.householdId,
  )..load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.householdName} · Anomalias')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          return Column(
            children: [
              ErrorBanner(message: _viewModel.errorMessage),
              _StatusFilterRow(
                selected: _viewModel.statusFilter,
                onSelected: (status) => _viewModel.load(statusFilter: status),
              ),
              Expanded(
                child: _viewModel.isLoading && _viewModel.anomalies.isEmpty
                    ? const LoadingState()
                    : RefreshIndicator(
                        onRefresh: () => _viewModel.load(
                          statusFilter: _viewModel.statusFilter,
                        ),
                        child: _viewModel.anomalies.isEmpty
                            ? ListView(
                                children: const [
                                  AppEmptyState(
                                    icon: Icons.check_circle_outline,
                                    title: 'Nenhuma anomalia encontrada',
                                    body:
                                        'Nada precisa da sua atenção agora.',
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _viewModel.anomalies.length,
                                itemBuilder: (context, index) {
                                  final anomaly = _viewModel.anomalies[index];
                                  return _AnomalyCard(
                                    anomaly: anomaly,
                                    isExplaining: _viewModel.isExplaining(
                                      anomaly.id,
                                    ),
                                    onExplain: () =>
                                        _viewModel.explain(anomaly.id),
                                    onConfirm: () => _viewModel.updateStatus(
                                      anomaly.id,
                                      'confirmed',
                                    ),
                                    onDismiss: () => _viewModel.updateStatus(
                                      anomaly.id,
                                      'dismissed',
                                    ),
                                  );
                                },
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          for (final entry in _statusFilters.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              onSelected: (_) => onSelected(entry.key),
            ),
        ],
      ),
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  const _AnomalyCard({
    required this.anomaly,
    required this.isExplaining,
    required this.onExplain,
    required this.onConfirm,
    required this.onDismiss,
  });

  final AnomalySummary anomaly;
  final bool isExplaining;
  final VoidCallback onExplain;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SeverityChip(severity: anomaly.severity),
                Text(
                  _statusLabel(anomaly.status),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(anomaly.summary),
            if (anomaly.explanation != null) ...[
              const SizedBox(height: 8),
              Text(
                anomaly.explanation!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: isExplaining ? null : onExplain,
                  child: isExplaining
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          anomaly.explanation == null
                              ? 'Explicar'
                              : 'Explicar novamente',
                        ),
                ),
                OutlinedButton(
                  onPressed: anomaly.status == 'confirmed' ? null : onConfirm,
                  child: const Text('Confirmar'),
                ),
                OutlinedButton(
                  onPressed: anomaly.status == 'dismissed' ? null : onDismiss,
                  child: const Text('Dispensar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
