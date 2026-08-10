import 'package:flutter/material.dart';

import '../../../../app/household_shell.dart';
import '../../../../data/models/extended_finance.dart';
import '../../../../data/repositories/dashboard_repository.dart';
import '../../../../data/repositories/extended_finance_repository.dart';
import '../../../../data/scope_controller.dart';
import '../../../core/formatting/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/period_pill.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import '../../dashboard/widgets/combo_cash_flow_chart.dart';
import '../../dashboard/widgets/cash_flow_chart_data.dart';
import '../../finances/view_models/finances_view_model.dart';
import '../widgets/monthly_spend_chart.dart';
import '../widgets/monthly_spend_chart_data.dart';

enum _AnalyticsSegment { spending, cashFlow, investments }

/// Análises tab — Gastos / Fluxo / Investimentos segmented view, per
/// `design.md`'s 6.4-6.6 and its Global Scope table: Gastos/Fluxo show the
/// period pill (fed into both [DashboardViewModel]'s cash-flow query and
/// [FinancesViewModel]'s category-breakdown query), Investimentos never does
/// (allocation is a today-snapshot, and there's no investment-value history
/// to period-filter yet — see `design.md`'s Open Questions). The shell hides
/// the period row for this whole tab and leaves it to this view to render
/// locally only for the two segments that use it — see `HouseholdScope`'s
/// doc comment. The category breakdown still renders as a plain list for
/// now (a proper horizontal-bar-list `CategoryBarList` component is a later
/// pass); the monthly-spend chart is the single-series stand-in noted in its
/// own file (per-member stacking needs a backend aggregation endpoint that
/// doesn't exist yet). Investimentos renders with plain list tiles,
/// intentionally unstyled per the mockup gap noted in `design.md`.
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
  late final DashboardViewModel _dashboardViewModel = DashboardViewModel(
    dashboardRepository: widget.dashboardRepository,
    householdId: widget.householdId,
  );

  late final FinancesViewModel _financesViewModel = FinancesViewModel(
    financeRepository: widget.financeRepository,
    householdId: widget.householdId,
  );

  _AnalyticsSegment _segment = _AnalyticsSegment.spending;
  ScopeController? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = HouseholdScope.of(context);
    if (_scope != scope) {
      _scope?.removeListener(_reload);
      _scope = scope;
      scope.addListener(_reload);
      _reload();
    }
  }

  void _reload() {
    final scope = _scope!;
    final memberIds = scope.selectedMemberIds.isEmpty ? null : scope.selectedMemberIds;
    final range = scope.resolveRange();
    _dashboardViewModel.load(startDate: range.start, endDate: range.end, memberIds: memberIds);
    _financesViewModel.load(
      startDate: range.start,
      endDate: range.end,
      memberIds: memberIds,
      comparePrevious: scope.comparePrevious,
    );
  }

  @override
  void dispose() {
    _scope?.removeListener(_reload);
    _dashboardViewModel.dispose();
    _financesViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Análises')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_dashboardViewModel, _financesViewModel]),
        builder: (context, _) {
          final isLoading =
              (_dashboardViewModel.isLoading && _dashboardViewModel.dashboard == null) ||
              (_financesViewModel.isLoading && _financesViewModel.categories.isEmpty);
          if (isLoading) {
            return const LoadingState();
          }

          final showsPeriod = _segment != _AnalyticsSegment.investments;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(message: _dashboardViewModel.errorMessage),
                ErrorBanner(message: _financesViewModel.errorMessage),
                AppSegmentedControl<_AnalyticsSegment>(
                  selected: _segment,
                  onChanged: (value) => setState(() => _segment = value),
                  segments: const [
                    AppSegment(value: _AnalyticsSegment.spending, label: 'Gastos'),
                    AppSegment(value: _AnalyticsSegment.cashFlow, label: 'Fluxo'),
                    AppSegment(value: _AnalyticsSegment.investments, label: 'Investimentos'),
                  ],
                ),
                if (showsPeriod) ...[
                  const SizedBox(height: 16),
                  Center(child: PeriodPill(controller: _scope!)),
                ],
                const SizedBox(height: 16),
                switch (_segment) {
                  _AnalyticsSegment.spending => _SpendingSection(
                    financesViewModel: _financesViewModel,
                    scope: _scope!,
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
  const _SpendingSection({required this.financesViewModel, required this.scope});

  final FinancesViewModel financesViewModel;
  final ScopeController scope;

  @override
  Widget build(BuildContext context) {
    final chartData = MonthlySpendChartData.fromMemberSpend(
      rows: financesViewModel.spendingByMember,
      members: scope.members,
      selectedMemberIds: scope.selectedMemberIds,
    );
    final categories = financesViewModel.categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!chartData.isEmpty) MonthlySpendChart(data: chartData),
        const SizedBox(height: 24),
        Text('Por categoria', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          const AppEmptyState(icon: Icons.pie_chart_outline, title: 'Nenhum gasto categorizado ainda')
        else
          for (final item in categories) _CategoryRow(item: item),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item});

  final CategoryBreakdownItem item;

  @override
  Widget build(BuildContext context) {
    final delta = _deltaLabel();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.category ?? 'Sem categoria'),
                if (delta != null)
                  Text(
                    delta,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatMoney(item.total, 'BRL'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// "+18% vs período anterior" — the bounded, numeric-only version of
  /// `design.md`'s "every figure carries a delta" rule for this pass (see
  /// the plan's "Deliberately deferred" note on ghosted chart series).
  String? _deltaLabel() {
    final previous = item.previousTotal;
    if (previous == null) return null;
    if (previous == 0) {
      return item.total == 0 ? null : 'novo vs período anterior';
    }
    final change = ((item.total - previous) / previous) * 100;
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(0)}% vs período anterior';
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
      return const AppEmptyState(icon: Icons.show_chart, title: 'Nenhum dado de fluxo de caixa ainda');
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
      return const AppEmptyState(icon: Icons.trending_up, title: 'Nenhum investimento sincronizado ainda');
    }
    return Column(
      children: [
        for (final investment in investments)
          Card(
            child: ListTile(
              title: Text(investment.name ?? 'Investimento'),
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
