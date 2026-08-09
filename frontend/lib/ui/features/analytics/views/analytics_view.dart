import 'package:flutter/material.dart';

import '../../../../data/repositories/dashboard_repository.dart';
import '../../../../data/repositories/extended_finance_repository.dart';
import '../../../core/formatting/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import '../../dashboard/widgets/combo_cash_flow_chart.dart';
import '../../dashboard/widgets/cash_flow_chart_data.dart';
import '../../finances/view_models/finances_view_model.dart';
import '../widgets/monthly_spend_chart.dart';
import '../widgets/monthly_spend_chart_data.dart';

enum _AnalyticsSegment { spending, cashFlow, investments }

/// Análises tab — Gastos / Fluxo / Investimentos segmented view, per
/// `design.md`'s 6.4-6.6. Reuses [DashboardViewModel] (for monthly cash-flow
/// series) and [FinancesViewModel] (for category breakdown + investments) —
/// no new backend endpoints this pass. The category breakdown still renders
/// as the OLD pie-chart widget's data via a plain list for now (a proper
/// horizontal-bar-list `CategoryBarList` component is a later pass); the
/// monthly-spend chart is the single-series stand-in noted in its own file
/// (per-member stacking needs a backend aggregation endpoint that doesn't
/// exist yet — see the phased implementation plan's Phase 3). Investimentos
/// renders with plain list tiles, intentionally unstyled per the mockup gap
/// noted in `design.md` (no mockup frame exists for this tab yet).
class AnalyticsView extends StatefulWidget {
  const AnalyticsView({
    super.key,
    required this.dashboardRepository,
    required this.financeRepository,
    required this.householdId,
  });

  final DashboardRepository dashboardRepository;
  final ExtendedFinanceRepository financeRepository;
  final String householdId;

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  late final _dashboardViewModel = DashboardViewModel(
    dashboardRepository: widget.dashboardRepository,
    householdId: widget.householdId,
  )..load();

  late final _financesViewModel = FinancesViewModel(
    financeRepository: widget.financeRepository,
    householdId: widget.householdId,
  )..load();

  _AnalyticsSegment _segment = _AnalyticsSegment.spending;

  @override
  void dispose() {
    _dashboardViewModel.dispose();
    _financesViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_dashboardViewModel, _financesViewModel]),
        builder: (context, _) {
          final isLoading =
              (_dashboardViewModel.isLoading && _dashboardViewModel.dashboard == null) ||
              (_financesViewModel.isLoading && _financesViewModel.categories.isEmpty);
          if (isLoading) {
            return const LoadingState();
          }

          return RefreshIndicator(
            onRefresh: () => Future.wait([_dashboardViewModel.load(), _financesViewModel.load()]),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(message: _dashboardViewModel.errorMessage),
                ErrorBanner(message: _financesViewModel.errorMessage),
                AppSegmentedControl<_AnalyticsSegment>(
                  selected: _segment,
                  onChanged: (value) => setState(() => _segment = value),
                  segments: const [
                    AppSegment(value: _AnalyticsSegment.spending, label: 'Spending'),
                    AppSegment(value: _AnalyticsSegment.cashFlow, label: 'Cash flow'),
                    AppSegment(value: _AnalyticsSegment.investments, label: 'Investments'),
                  ],
                ),
                const SizedBox(height: 16),
                switch (_segment) {
                  _AnalyticsSegment.spending => _SpendingSection(
                    dashboardViewModel: _dashboardViewModel,
                    financesViewModel: _financesViewModel,
                  ),
                  _AnalyticsSegment.cashFlow => _CashFlowSection(dashboardViewModel: _dashboardViewModel),
                  _AnalyticsSegment.investments => _InvestmentsSection(financesViewModel: _financesViewModel),
                },
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SpendingSection extends StatelessWidget {
  const _SpendingSection({required this.dashboardViewModel, required this.financesViewModel});

  final DashboardViewModel dashboardViewModel;
  final FinancesViewModel financesViewModel;

  @override
  Widget build(BuildContext context) {
    final monthlyCashFlow = dashboardViewModel.dashboard?.monthlyCashFlow ?? const [];
    final chartData = MonthlySpendChartData.fromMonthlyCashFlow(monthlyCashFlow);
    final categories = financesViewModel.categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!chartData.isEmpty) MonthlySpendChart(data: chartData),
        const SizedBox(height: 24),
        Text('By category', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          const AppEmptyState(icon: Icons.pie_chart_outline, title: 'No categorized spending yet')
        else
          for (final item in categories)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(item.category ?? 'Uncategorized')),
                  Text(
                    formatMoney(item.total, 'BRL'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _CashFlowSection extends StatelessWidget {
  const _CashFlowSection({required this.dashboardViewModel});

  final DashboardViewModel dashboardViewModel;

  @override
  Widget build(BuildContext context) {
    final monthlyCashFlow = dashboardViewModel.dashboard?.monthlyCashFlow ?? const [];
    final chartData = CashFlowChartData.fromMonthlyCashFlow(monthlyCashFlow);
    if (chartData.isEmpty) {
      return const AppEmptyState(icon: Icons.show_chart, title: 'No cash flow data yet');
    }
    return ComboCashFlowChart(data: chartData);
  }
}

class _InvestmentsSection extends StatelessWidget {
  const _InvestmentsSection({required this.financesViewModel});

  final FinancesViewModel financesViewModel;

  @override
  Widget build(BuildContext context) {
    final investments = financesViewModel.investments;
    if (investments.isEmpty) {
      return const AppEmptyState(icon: Icons.trending_up, title: 'No investments synced yet');
    }
    return Column(
      children: [
        for (final investment in investments)
          Card(
            child: ListTile(
              title: Text(investment.name ?? 'Investment'),
              subtitle: Text(investment.subtype ?? investment.type ?? ''),
              trailing: Text(
                investment.value == null ? '—' : formatMoney(investment.value!, investment.currencyCode),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
      ],
    );
  }
}
