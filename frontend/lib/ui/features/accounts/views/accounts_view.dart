import 'package:flutter/material.dart';

import '../../../../data/models/dashboard.dart';
import '../../../../data/repositories/dashboard_repository.dart';
import '../../../core/formatting/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';

enum _AccountsSegment { balances, statement }

/// Contas tab — Saldos (balances) / Extrato (statement) segmented view, per
/// `design.md`'s 6.2/6.3. Reuses [DashboardViewModel] for now (same data the
/// Início tab loads) rather than a new endpoint — no backend changes this
/// pass. Real per-member grouping, utilization thresholds, search/filter,
/// and export are follow-up work gated on backend attribution (see the
/// phased implementation plan's Phase 2).
class AccountsView extends StatefulWidget {
  const AccountsView({
    super.key,
    required this.dashboardRepository,
    required this.householdId,
  });

  final DashboardRepository dashboardRepository;
  final String householdId;

  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  late final _viewModel = DashboardViewModel(
    dashboardRepository: widget.dashboardRepository,
    householdId: widget.householdId,
  )..load();

  _AccountsSegment _segment = _AccountsSegment.statement;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contas')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final dashboard = _viewModel.dashboard;
          if (_viewModel.isLoading && dashboard == null) {
            return const LoadingState();
          }

          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(message: _viewModel.errorMessage),
                AppSegmentedControl<_AccountsSegment>(
                  selected: _segment,
                  onChanged: (value) => setState(() => _segment = value),
                  segments: const [
                    AppSegment(value: _AccountsSegment.balances, label: 'Saldos'),
                    AppSegment(value: _AccountsSegment.statement, label: 'Extrato'),
                  ],
                ),
                const SizedBox(height: 16),
                if (dashboard == null)
                  const SizedBox.shrink()
                else if (_segment == _AccountsSegment.balances)
                  _BalancesList(dashboard: dashboard)
                else
                  _StatementList(dashboard: dashboard),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalancesList extends StatelessWidget {
  const _BalancesList({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final accounts = dashboard.accounts;
    if (accounts.isEmpty) {
      return const AppEmptyState(
        icon: Icons.account_balance_outlined,
        title: 'Nenhuma conta ainda',
        body: 'Conecte a primeira conta para começar.',
      );
    }
    return Column(
      children: [
        for (final account in accounts)
          Card(
            child: ListTile(
              title: Text(account.name ?? 'Conta'),
              subtitle: Text(account.subtype ?? account.type ?? ''),
              trailing: Text(
                account.balance == null ? '—' : formatMoney(account.balance!, account.currencyCode),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatementList extends StatelessWidget {
  const _StatementList({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final transactions = dashboard.recentTransactions;
    if (transactions.isEmpty) {
      return const AppEmptyState(icon: Icons.receipt_long_outlined, title: 'Nenhuma movimentação ainda');
    }
    return Column(
      children: [
        for (final txn in transactions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(txn.description ?? 'Movimentação'),
            subtitle: Text(txn.accountName ?? ''),
            trailing: Text(
              formatMoney(txn.amount, txn.currencyCode),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
      ],
    );
  }
}
