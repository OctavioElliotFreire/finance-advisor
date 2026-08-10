import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/household_shell.dart';
import '../../../../data/models/dashboard.dart';
import '../../../../data/repositories/dashboard_repository.dart';
import '../../../../data/scope_controller.dart';
import '../../../core/formatting/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/period_pill.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';

enum _AccountsSegment { balances, statement }

/// Contas tab — Saldos (balances) / Extrato (statement) segmented view, per
/// `design.md`'s 6.2/6.3 and its Global Scope table: Saldos shows the member
/// filter but never the period pill (balances are a snapshot, not a period
/// sum); Extrato shows both. The shell (`HouseholdShell`) deliberately hides
/// the period row for the whole Contas tab and leaves it to this view to
/// render locally only for Extrato — see `HouseholdScope`'s doc comment.
/// Saldos still reuses [DashboardViewModel] (member-filterable, no date
/// range); Extrato now has its own paginated `GET /transactions` call
/// instead of the dashboard's fixed-10 teaser.
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
  late final DashboardViewModel _balancesViewModel = DashboardViewModel(
    dashboardRepository: widget.dashboardRepository,
    householdId: widget.householdId,
  );

  _AccountsSegment _segment = _AccountsSegment.statement;
  ScopeController? _scope;

  List<TransactionSummary> _transactions = const [];
  bool _isLoadingTransactions = false;
  String? _transactionsError;

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
    _balancesViewModel.load(memberIds: memberIds);
    unawaited(_loadTransactions());
  }

  Future<void> _loadTransactions() async {
    final scope = _scope!;
    final range = scope.resolveRange();
    setState(() => _isLoadingTransactions = true);
    try {
      final transactions = await widget.dashboardRepository.listTransactions(
        widget.householdId,
        startDate: range.start,
        endDate: range.end,
        memberIds: scope.selectedMemberIds.isEmpty ? null : scope.selectedMemberIds,
      );
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _transactionsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _transactionsError = 'Não foi possível carregar as movimentações.');
    } finally {
      if (mounted) setState(() => _isLoadingTransactions = false);
    }
  }

  @override
  void dispose() {
    _scope?.removeListener(_reload);
    _balancesViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contas')),
      body: ListenableBuilder(
        listenable: _balancesViewModel,
        builder: (context, _) {
          final dashboard = _balancesViewModel.dashboard;
          final isBalances = _segment == _AccountsSegment.balances;
          if (isBalances && _balancesViewModel.isLoading && dashboard == null) {
            return const LoadingState();
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ErrorBanner(
                  message: isBalances ? _balancesViewModel.errorMessage : _transactionsError,
                ),
                AppSegmentedControl<_AccountsSegment>(
                  selected: _segment,
                  onChanged: (value) => setState(() => _segment = value),
                  segments: const [
                    AppSegment(value: _AccountsSegment.balances, label: 'Saldos'),
                    AppSegment(value: _AccountsSegment.statement, label: 'Extrato'),
                  ],
                ),
                const SizedBox(height: 16),
                if (isBalances)
                  if (dashboard == null)
                    const SizedBox.shrink()
                  else
                    _BalancesList(dashboard: dashboard)
                else ...[
                  Center(child: PeriodPill(controller: _scope!)),
                  const SizedBox(height: 16),
                  if (_isLoadingTransactions && _transactions.isEmpty)
                    const LoadingState()
                  else
                    _StatementList(transactions: _transactions),
                ],
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
  const _StatementList({required this.transactions});

  final List<TransactionSummary> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const AppEmptyState(icon: Icons.receipt_long_outlined, title: 'Nenhuma movimentação ainda');
    }
    return Column(
      children: [
        for (final txn in transactions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(txn.description ?? 'Movimentação'),
            subtitle: Text(
              '${txn.accountName ?? ''} · ${formatShortDate(txn.transactionDate)}',
            ),
            trailing: Text(
              formatMoney(txn.amount, txn.currencyCode),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
      ],
    );
  }
}
