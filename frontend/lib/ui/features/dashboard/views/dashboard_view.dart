import 'package:flutter/material.dart';

import '../../../../data/models/dashboard.dart';
import '../../../../data/repositories/dashboard_repository.dart';
import '../../../core/formatting/money.dart';
import '../../../core/widgets/error_banner.dart';
import '../view_models/dashboard_view_model.dart';

const _wideLayoutBreakpoint = 720.0;

class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.dashboardRepository,
    required this.householdId,
    required this.householdName,
    required this.onManageConnections,
    required this.onViewFinances,
    required this.onViewAnomalies,
    required this.onManageMembers,
  });

  final DashboardRepository dashboardRepository;
  final String householdId;
  final String householdName;
  final VoidCallback onManageConnections;
  final VoidCallback onViewFinances;
  final VoidCallback onViewAnomalies;
  final VoidCallback onManageMembers;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late final _viewModel = DashboardViewModel(
    dashboardRepository: widget.dashboardRepository,
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
      appBar: AppBar(
        title: Text(widget.householdName),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart),
            tooltip: 'Finances',
            onPressed: widget.onViewFinances,
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded),
            tooltip: 'Anomalies',
            onPressed: widget.onViewAnomalies,
          ),
          IconButton(
            icon: const Icon(Icons.account_balance),
            tooltip: 'Connections',
            onPressed: widget.onManageConnections,
          ),
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'Members',
            onPressed: widget.onManageMembers,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading && _viewModel.dashboard == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final dashboard = _viewModel.dashboard;
          return RefreshIndicator(
            onRefresh: _viewModel.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(message: _viewModel.errorMessage),
                if (dashboard == null && !_viewModel.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: Text('Could not load the dashboard.')),
                  )
                else if (dashboard != null)
                  _DashboardBody(dashboard: dashboard),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
        final overview = _OverviewSection(dashboard: dashboard);
        final cashFlow = _CashFlowSection(monthlyCashFlow: dashboard.monthlyCashFlow);
        final transactions = _RecentTransactionsSection(
          transactions: dashboard.recentTransactions,
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [overview, const SizedBox(height: 16), cashFlow, const SizedBox(height: 16), transactions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [overview, const SizedBox(height: 16), cashFlow],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: transactions),
          ],
        );
      },
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.dashboard});

  final Dashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final syncStatus = dashboard.syncStatus;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total balance', style: Theme.of(context).textTheme.titleMedium),
                _SyncStatusChip(syncStatus: syncStatus),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatMoney(dashboard.totalBalance, _dominantCurrency(dashboard)),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (dashboard.accounts.isEmpty)
              const Text('No accounts synced yet.')
            else
              for (final account in dashboard.accounts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(account.name ?? account.type ?? 'Account'),
                      ),
                      Text(formatMoney(account.balance ?? 0, account.currencyCode)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _dominantCurrency(Dashboard dashboard) {
    if (dashboard.accounts.isEmpty) return 'BRL';
    return dashboard.accounts.first.currencyCode;
  }
}

class _SyncStatusChip extends StatelessWidget {
  const _SyncStatusChip({required this.syncStatus});

  final SyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
    final status = syncStatus.status;
    if (status == null) {
      return const Chip(label: Text('Never synced'));
    }

    final (color, label) = switch (status) {
      'completed' => (Colors.green, 'Synced'),
      'partially_completed' => (Colors.orange, 'Partially synced'),
      'failed' => (Colors.red, 'Sync failed'),
      'running' => (Colors.blue, 'Syncing…'),
      _ => (Colors.grey, status),
    };

    return Chip(
      label: Text(label),
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
    );
  }
}

class _CashFlowSection extends StatelessWidget {
  const _CashFlowSection({required this.monthlyCashFlow});

  final List<MonthlyCashFlow> monthlyCashFlow;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly cash flow', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (monthlyCashFlow.isEmpty)
              const Text('No transactions synced yet.')
            else
              for (final month in monthlyCashFlow) _CashFlowRow(month: month),
          ],
        ),
      ),
    );
  }
}

class _CashFlowRow extends StatelessWidget {
  const _CashFlowRow({required this.month});

  final MonthlyCashFlow month;

  @override
  Widget build(BuildContext context) {
    final netColor = month.net >= 0 ? Colors.green : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(formatMonth(month.month))),
          Expanded(
            child: Text('In ${formatMoney(month.income, 'BRL')} · Out ${formatMoney(month.expenses, 'BRL')}'),
          ),
          Text(
            formatMoney(month.net, 'BRL'),
            style: TextStyle(color: netColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection({required this.transactions});

  final List<TransactionSummary> transactions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No transactions synced yet.'),
              )
            else
              for (final txn in transactions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(txn.description ?? 'Transaction'),
                  subtitle: Text(
                    '${txn.accountName ?? ''} · ${formatShortDate(txn.transactionDate)}',
                  ),
                  trailing: Text(
                    formatMoney(txn.amount, txn.currencyCode),
                    style: TextStyle(
                      color: txn.amount >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
