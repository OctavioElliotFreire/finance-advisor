import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/household_shell.dart';
import '../../../../data/models/dashboard.dart';
import '../../../../data/models/extended_finance.dart';
import '../../../../data/models/household_member.dart';
import '../../../../data/repositories/dashboard_repository.dart';
import '../../../../data/repositories/extended_finance_repository.dart';
import '../../../../data/scope_controller.dart';
import '../../../core/formatting/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/member_dot.dart';
import '../../../core/widgets/period_pill.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/status_chip.dart';
import '../../dashboard/view_models/dashboard_view_model.dart';
import '../../dashboard/widgets/dashboard_summary_data.dart';

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
    required this.financeRepository,
    required this.householdId,
  });

  final DashboardRepository dashboardRepository;
  final ExtendedFinanceRepository financeRepository;
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
  String? _statementFilter;

  List<CreditCardBillSummary> _creditCardBills = const [];

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
    unawaited(_loadCreditCardBills(memberIds));
  }

  /// Fatura data for Saldos' credit-card rows — secondary to the account
  /// list itself, so a failure here just means cards fall back to showing
  /// no fatura line, same non-fatal pattern as Início's supplemental fetch.
  Future<void> _loadCreditCardBills(Set<String>? memberIds) async {
    try {
      final bills = await widget.financeRepository.getCreditCardBills(
        widget.householdId,
        memberIds: memberIds,
      );
      if (!mounted) return;
      setState(() => _creditCardBills = bills);
    } catch (_) {
      // Non-fatal — see doc comment above.
    }
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

  /// Client-side only — Extrato fetches a single unpaginated page for the
  /// selected period already (no "load more" UI exists today), so filter
  /// pills narrow that same batch rather than triggering a new fetch.
  List<TransactionSummary> _applyStatementFilter(List<TransactionSummary> transactions, String? filter) {
    return switch (filter) {
      'flagged' => transactions.where((t) => t.isFlagged).toList(),
      'in' => transactions.where((t) => t.amount > 0).toList(),
      'out' => transactions.where((t) => t.amount < 0).toList(),
      _ => transactions,
    };
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
            child: AppGridPage(
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
                    _BalancesList(
                      dashboard: dashboard,
                      creditCardBills: _creditCardBills,
                      members: _scope!.members,
                    )
                else ...[
                  Center(child: PeriodPill(controller: _scope!)),
                  const SizedBox(height: 16),
                  _StatementFilterRow(
                    selected: _statementFilter,
                    onSelected: (value) => setState(() => _statementFilter = value),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingTransactions && _transactions.isEmpty)
                    const LoadingState()
                  else
                    _StatementList(
                      transactions: _applyStatementFilter(_transactions, _statementFilter),
                      accounts: dashboard?.accounts ?? const [],
                      members: _scope!.members,
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Reuses `StatusChip.connectionStatus`'s own tone mapping
/// (`frontend/lib/ui/core/widgets/status_chip.dart`) rather than
/// re-deriving a separate "which statuses are broken" vocabulary — a
/// connection status counts as broken here exactly when that widget would
/// render it as a negative-tone chip.
bool _isConnectionBroken(String? status) =>
    status != null && StatusChip.connectionStatus(status).tone == StatusTone.negative;

class _AccountGroup {
  const _AccountGroup({required this.label, required this.color, required this.accounts});

  final String label;
  final Color color;
  final List<AccountSummary> accounts;
}

class _BalancesList extends StatelessWidget {
  const _BalancesList({required this.dashboard, required this.creditCardBills, required this.members});

  final Dashboard dashboard;
  final List<CreditCardBillSummary> creditCardBills;
  final List<HouseholdMember> members;

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

    final currentBills = currentBillsByAccount(creditCardBills);
    final groups = _groupByMember(accounts, members);

    return Column(
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                MemberDot(color: group.color),
                const SizedBox(width: 8),
                Text(group.label, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
          for (final account in group.accounts)
            _AccountRow(account: account, currentBill: currentBills[account.id]),
        ],
      ],
    );
  }

  List<_AccountGroup> _groupByMember(List<AccountSummary> accounts, List<HouseholdMember> members) {
    final byMember = <String?, List<AccountSummary>>{};
    for (final account in accounts) {
      byMember.putIfAbsent(account.ownerMemberId, () => []).add(account);
    }
    final groups = <_AccountGroup>[];
    for (var i = 0; i < members.length; i++) {
      final memberAccounts = byMember[members[i].id];
      if (memberAccounts != null) {
        groups.add(
          _AccountGroup(
            label: members[i].email,
            color: AppMemberColors.forIndex(i),
            accounts: memberAccounts,
          ),
        );
      }
    }
    final unattributed = byMember[null];
    if (unattributed != null) {
      groups.add(_AccountGroup(label: 'Outros', color: AppMemberColors.outros, accounts: unattributed));
    }
    return groups;
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.currentBill});

  final AccountSummary account;
  final CreditCardBillSummary? currentBill;

  @override
  Widget build(BuildContext context) {
    if (_isConnectionBroken(account.connectionStatus)) {
      return Card(
        child: ListTile(
          title: Text(account.name ?? 'Conta'),
          subtitle: Text(
            'Sem sincronizar',
            style: TextStyle(color: AppPalette.inkMuted),
          ),
        ),
      );
    }

    if (account.type == 'CREDIT') {
      final available = account.availableCreditLimit;
      final bill = currentBill;
      return Card(
        child: ListTile(
          title: Text(account.name ?? 'Conta'),
          subtitle: bill == null
              ? null
              : Text(
                  'Fatura ${formatMoney(bill.totalAmount ?? 0, account.currencyCode)}'
                  '${bill.closingDate == null ? '' : ' · fecha ${formatShortDate(bill.closingDate!)}'}'
                  '${bill.dueDate == null ? '' : ' · vence ${formatShortDate(bill.dueDate!)}'}',
                ),
          trailing: Text(
            available == null ? '—' : formatMoney(available, account.currencyCode),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: _utilizationColor(context, account)),
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        title: Text(account.name ?? 'Conta'),
        subtitle: Text(account.subtype ?? account.type ?? ''),
        trailing: Text(
          account.balance == null ? '—' : formatMoney(account.balance!, account.currencyCode),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }

  /// Utilization thresholds per `design.md`'s §6.2: `< 30%` default ink
  /// (`null` here, letting the theme's normal text color apply), `30-70%`
  /// warning, `> 70%` danger (`ColorScheme.error`, reused directly per
  /// `AppSemanticColors`'s own doc comment rather than a bespoke danger
  /// token).
  Color? _utilizationColor(BuildContext context, AccountSummary account) {
    final limit = account.creditLimit;
    final available = account.availableCreditLimit;
    if (limit == null || limit <= 0 || available == null) return null;
    final utilization = (limit - available) / limit;
    if (utilization > 0.7) return Theme.of(context).colorScheme.error;
    if (utilization > 0.3) return context.semanticColors.warning;
    return null;
  }
}

// Filter pills per design.md's §6.3 — `Parcelados` is deliberately omitted:
// no parcela data exists on Transaction yet (same backend gap noted
// elsewhere in this codebase), so there's nothing for that chip to filter.
const _statementFilters = <String?, String>{
  null: 'Todos',
  'flagged': 'Sinalizados',
  'in': 'Entradas',
  'out': 'Saídas',
};

class _StatementFilterRow extends StatelessWidget {
  const _StatementFilterRow({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in _statementFilters.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: selected == entry.key,
            onSelected: (_) => onSelected(entry.key),
          ),
      ],
    );
  }
}

class _StatementGroup {
  const _StatementGroup({
    required this.label,
    required this.color,
    required this.number,
    required this.transactions,
  });

  final String label;
  final Color color;
  final String? number;
  final List<TransactionSummary> transactions;
}

/// Groups transactions by account for Extrato's section headers — ordered
/// by the accounts list's own existing order (`Account.type, Account.name`,
/// same as Saldos) for consistency between the two Contas segments.
/// Substitutes the account's own name for the spec's "institution" (no
/// institution data is persisted anywhere yet — a documented gap, same
/// class as the parcela one above) — and degrades to a generic "Conta"
/// bucket for any transaction whose account isn't in `accounts` yet
/// (e.g. that fetch hasn't completed), rather than crashing.
List<_StatementGroup> _groupByAccount(
  List<TransactionSummary> transactions,
  List<AccountSummary> accounts,
  List<HouseholdMember> members,
) {
  final memberIndex = {for (var i = 0; i < members.length; i++) members[i].id: i};
  final byAccount = <String, List<TransactionSummary>>{};
  for (final txn in transactions) {
    byAccount.putIfAbsent(txn.accountId, () => []).add(txn);
  }

  final groups = <_StatementGroup>[];
  for (final account in accounts) {
    final txns = byAccount.remove(account.id);
    if (txns == null) continue;
    final memberIdx = account.ownerMemberId == null ? null : memberIndex[account.ownerMemberId];
    groups.add(
      _StatementGroup(
        label: account.name ?? 'Conta',
        color: memberIdx == null ? AppMemberColors.outros : AppMemberColors.forIndex(memberIdx),
        number: account.number,
        transactions: txns,
      ),
    );
  }
  for (final leftover in byAccount.values) {
    groups.add(_StatementGroup(label: 'Conta', color: AppMemberColors.outros, number: null, transactions: leftover));
  }
  return groups;
}

class _StatementList extends StatelessWidget {
  const _StatementList({required this.transactions, required this.accounts, required this.members});

  final List<TransactionSummary> transactions;
  final List<AccountSummary> accounts;
  final List<HouseholdMember> members;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const AppEmptyState(icon: Icons.receipt_long_outlined, title: 'Nenhuma movimentação ainda');
    }

    final groups = _groupByAccount(transactions, accounts, members);

    return Column(
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                MemberDot(color: group.color),
                const SizedBox(width: 8),
                Text(group.label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                Text(
                  formatMaskedAccountNumber(group.number),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          for (final txn in group.transactions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: txn.isFlagged ? const Icon(Icons.flag, size: 18) : null,
              title: Text(txn.description ?? 'Movimentação'),
              subtitle: Text(
                txn.category == null
                    ? formatDayMonth(txn.transactionDate)
                    : '${formatDayMonth(txn.transactionDate)} · ${txn.category}',
              ),
              trailing: Text(
                formatMoney(txn.amount, txn.currencyCode),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
        ],
      ],
    );
  }
}
