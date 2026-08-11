import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/household_shell.dart';
import '../../../../data/models/dashboard.dart';
import '../../../../data/models/extended_finance.dart';
import '../../../../data/models/household_member.dart';
import '../../../../data/repositories/anomaly_repository.dart';
import '../../../../data/repositories/dashboard_repository.dart';
import '../../../../data/repositories/extended_finance_repository.dart';
import '../../../../data/scope_controller.dart';
import '../../../core/formatting/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/dashboard_view_model.dart';
import '../widgets/cash_flow_chart.dart';
import '../widgets/cash_flow_chart_data.dart';
import '../widgets/dashboard_summary_data.dart';

/// Início — "are we okay this month?" per `design.md`'s §6.1. Full rebuild
/// replacing the old Saldo-total-card/cash-flow/recent-transactions
/// dashboard: hero (Gastos do mês/Entradas/Sobrou), credit block, fatura
/// warning, alerts count, per-member spend, sync footer — see
/// `dashboard_summary_data.dart` for the pure calculations behind each.
/// Cash flow chart and recent transactions are kept as-is from the prior
/// version (not spec'd by §6.1, but not superseded by it either).
class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.dashboardRepository,
    required this.financeRepository,
    required this.anomalyRepository,
    required this.householdId,
    required this.householdName,
    required this.onManageConnections,
    required this.onViewFinances,
    required this.onViewAnomalies,
    required this.onManageMembers,
    required this.onOpenAssistant,
  });

  final DashboardRepository dashboardRepository;
  final ExtendedFinanceRepository financeRepository;
  final AnomalyRepository anomalyRepository;
  final String householdId;
  final String householdName;
  final VoidCallback onManageConnections;
  final VoidCallback onViewFinances;
  final VoidCallback onViewAnomalies;
  final VoidCallback onManageMembers;
  final VoidCallback onOpenAssistant;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late final DashboardViewModel _viewModel = DashboardViewModel(
    dashboardRepository: widget.dashboardRepository,
    householdId: widget.householdId,
  );
  ScopeController? _scope;

  List<CreditCardBillSummary> _creditCardBills = const [];
  List<MemberMonthlySpend> _memberSpend = const [];
  int _openAnomalyCount = 0;

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
    final range = scope.resolveRange();
    final memberIds = scope.selectedMemberIds.isEmpty ? null : scope.selectedMemberIds;
    _viewModel.load(startDate: range.start, endDate: range.end, memberIds: memberIds);
    unawaited(_loadSupplementalData(range.start, range.end, memberIds));
  }

  /// Credit-card bills (for the fatura warning), per-member spend (for "Por
  /// membro"), and the open-anomaly count (for the alerts row) — all
  /// secondary to the main dashboard payload above, so a failure here
  /// degrades those sections quietly rather than blocking the page (same
  /// non-fatal pattern `HouseholdShell._loadMembers()` already uses for the
  /// member-chip row).
  Future<void> _loadSupplementalData(
    DateTime startDate,
    DateTime endDate,
    Set<String>? memberIds,
  ) async {
    try {
      final results = await Future.wait([
        widget.financeRepository.getCreditCardBills(widget.householdId, memberIds: memberIds),
        widget.financeRepository.getSpendingByMember(
          widget.householdId,
          startDate: startDate,
          endDate: endDate,
          memberIds: memberIds,
        ),
        widget.anomalyRepository.listAnomalies(widget.householdId, statusFilter: 'open'),
      ]);
      if (!mounted) return;
      setState(() {
        _creditCardBills = results[0] as List<CreditCardBillSummary>;
        _memberSpend = results[1] as List<MemberMonthlySpend>;
        _openAnomalyCount = (results[2] as List).length;
      });
    } catch (_) {
      // Non-fatal — see doc comment above.
    }
  }

  @override
  void dispose() {
    _scope?.removeListener(_reload);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final dashboard = _viewModel.dashboard;
        return Scaffold(
          appBar: AppBar(
            title: Text(dashboard?.householdName ?? widget.householdName),
            actions: [
              IconButton(
                icon: const Icon(Icons.pie_chart),
                tooltip: 'Finanças',
                onPressed: widget.onViewFinances,
              ),
              IconButton(
                icon: const Icon(Icons.warning_amber_rounded),
                tooltip: 'Anomalias',
                onPressed: widget.onViewAnomalies,
              ),
              IconButton(
                icon: const Icon(Icons.account_balance),
                tooltip: 'Conexões',
                onPressed: widget.onManageConnections,
              ),
              IconButton(
                icon: const Icon(Icons.group),
                tooltip: 'Membros',
                onPressed: widget.onManageMembers,
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Assistente',
                onPressed: widget.onOpenAssistant,
              ),
            ],
          ),
          body: Builder(
            builder: (context) {
              if (_viewModel.isLoading && dashboard == null) {
                return const LoadingState();
              }

              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: AppGridPage(
                  children: [
                    ErrorBanner(message: _viewModel.errorMessage),
                    if (dashboard == null && !_viewModel.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text('Não foi possível carregar o painel.'),
                        ),
                      )
                    else if (dashboard != null)
                      _DashboardBody(
                        dashboard: dashboard,
                        creditCardBills: _creditCardBills,
                        memberSpend: _memberSpend,
                        openAnomalyCount: _openAnomalyCount,
                        members: _scope!.members,
                        onViewAnomalies: widget.onViewAnomalies,
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.dashboard,
    required this.creditCardBills,
    required this.memberSpend,
    required this.openAnomalyCount,
    required this.members,
    required this.onViewAnomalies,
  });

  final Dashboard dashboard;
  final List<CreditCardBillSummary> creditCardBills;
  final List<MemberMonthlySpend> memberSpend;
  final int openAnomalyCount;
  final List<HouseholdMember> members;
  final VoidCallback onViewAnomalies;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kWideBreakpoint;

        final primary = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroCard(monthlyCashFlow: dashboard.monthlyCashFlow, creditCardBills: creditCardBills),
            const SizedBox(height: 16),
            _CreditBlockCard(accounts: dashboard.accounts),
            _FaturaWarningCard(bills: creditCardBills, accounts: dashboard.accounts),
            _AlertsRow(count: openAnomalyCount, onTap: onViewAnomalies),
            const SizedBox(height: 16),
            _CashFlowSection(monthlyCashFlow: dashboard.monthlyCashFlow),
            const SizedBox(height: 16),
            _MemberSpendCard(rows: memberSpendRows(memberSpend, members)),
            const SizedBox(height: 16),
            _SyncFooter(syncStatus: dashboard.syncStatus),
          ],
        );
        final transactions = _RecentTransactionsSection(
          transactions: dashboard.recentTransactions,
        );

        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [primary, const SizedBox(height: 16), transactions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: primary),
            const SizedBox(width: 16),
            Expanded(child: transactions),
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.monthlyCashFlow, required this.creditCardBills});

  final List<MonthlyCashFlow> monthlyCashFlow;
  final List<CreditCardBillSummary> creditCardBills;

  @override
  Widget build(BuildContext context) {
    final hero = HeroSummary.fromMonthlyCashFlow(monthlyCashFlow);
    final committed = committedTotal(creditCardBills);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gastos do mês', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              formatMoney(hero.expenses, 'BRL'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Realizado · Comprometido ${formatMoney(committed, 'BRL')}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Entradas ${formatMoney(hero.income, 'BRL')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  'Sobrou ${formatMoney(hero.sobrou, 'BRL')}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditBlockCard extends StatelessWidget {
  const _CreditBlockCard({required this.accounts});

  final List<AccountSummary> accounts;

  @override
  Widget build(BuildContext context) {
    final credit = CreditBlockSummary.fromAccounts(accounts);
    if (!credit.hasCards) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Limite disponível', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '${formatMoney(credit.availableTotal, 'BRL')} de ${formatMoney(credit.limitTotal, 'BRL')} · '
                '${credit.cardCount} ${credit.cardCount == 1 ? 'cartão' : 'cartões'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaturaWarningCard extends StatelessWidget {
  const _FaturaWarningCard({required this.bills, required this.accounts});

  final List<CreditCardBillSummary> bills;
  final List<AccountSummary> accounts;

  @override
  Widget build(BuildContext context) {
    final warning = pickFaturaWarning(bills, accounts);
    if (warning == null) return const SizedBox.shrink();
    final days = warning.daysUntilDue;
    final dueLabel = days <= 0 ? 'vence hoje' : 'vence em $days ${days == 1 ? 'dia' : 'dias'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: context.semanticColors.warningContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Fatura do ${warning.accountName} $dueLabel · ${formatMoney(warning.bill.totalAmount ?? 0, 'BRL')}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.semanticColors.onWarningContainer),
          ),
        ),
      ),
    );
  }
}

class _AlertsRow extends StatelessWidget {
  const _AlertsRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count ${count == 1 ? 'cobrança incomum' : 'cobranças incomuns'} para revisar',
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberSpendCard extends StatelessWidget {
  const _MemberSpendCard({required this.rows});

  final List<MemberSpendRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Por membro', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, color: row.color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(row.label)),
                    Text(formatMoney(row.total, 'BRL')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncFooter extends StatelessWidget {
  const _SyncFooter({required this.syncStatus});

  final SyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
    if (syncStatus.totalConnections <= 0) return const SizedBox.shrink();
    final updatedAt = syncStatus.updatedAt;
    final suffix = updatedAt == null ? '' : ' ${formatRelativeTime(updatedAt)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '${syncStatus.syncedConnections} de ${syncStatus.totalConnections} contas atualizadas$suffix',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
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
            Text(
              'Fluxo de caixa mensal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (monthlyCashFlow.isEmpty)
              const Text('Nenhuma movimentação sincronizada ainda.')
            else
              CashFlowChart(
                data: CashFlowChartData.fromMonthlyCashFlow(monthlyCashFlow),
              ),
          ],
        ),
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
            Text(
              'Movimentações recentes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Nenhuma movimentação sincronizada ainda.'),
              )
            else
              for (final txn in transactions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(txn.description ?? 'Movimentação'),
                  subtitle: Text(
                    '${txn.accountName ?? ''} · ${formatShortDate(txn.transactionDate)}',
                  ),
                  trailing: Text(
                    formatMoney(txn.amount, txn.currencyCode),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
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
