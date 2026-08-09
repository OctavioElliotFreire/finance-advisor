import 'package:flutter/material.dart';

import '../../../../data/models/extended_finance.dart';
import '../../../../data/repositories/extended_finance_repository.dart';
import '../../../core/formatting/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_banner.dart';
import '../../../core/widgets/loading_state.dart';
import '../view_models/finances_view_model.dart';
import '../widgets/balance_history_chart.dart';
import '../widgets/balance_history_chart_data.dart';
import '../widgets/category_breakdown_chart.dart';
import '../widgets/category_breakdown_chart_data.dart';

class FinancesView extends StatefulWidget {
  const FinancesView({
    super.key,
    required this.financeRepository,
    required this.householdId,
    required this.householdName,
  });

  final ExtendedFinanceRepository financeRepository;
  final String householdId;
  final String householdName;

  @override
  State<FinancesView> createState() => _FinancesViewState();
}

class _FinancesViewState extends State<FinancesView> {
  late final _viewModel = FinancesViewModel(
    financeRepository: widget.financeRepository,
    householdId: widget.householdId,
  )..load();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.householdName} · Finances'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Investments'),
              Tab(text: 'Loans'),
              Tab(text: 'Bills'),
              Tab(text: 'Balance History'),
              Tab(text: 'Categories'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            if (_viewModel.isLoading &&
                _viewModel.investments.isEmpty &&
                _viewModel.loans.isEmpty &&
                _viewModel.bills.isEmpty) {
              return const LoadingState();
            }

            return RefreshIndicator(
              onRefresh: _viewModel.load,
              child: Column(
                children: [
                  ErrorBanner(message: _viewModel.errorMessage),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _InvestmentsTab(investments: _viewModel.investments),
                        _LoansTab(loans: _viewModel.loans),
                        _BillsTab(bills: _viewModel.bills),
                        _BalanceHistoryTab(points: _viewModel.balanceHistory),
                        _CategoriesTab(categories: _viewModel.categories),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InvestmentsTab extends StatelessWidget {
  const _InvestmentsTab({required this.investments});

  final List<InvestmentSummary> investments;

  @override
  Widget build(BuildContext context) {
    if (investments.isEmpty) {
      return const AppEmptyState(
        icon: Icons.trending_up_outlined,
        title: 'No investments synced yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: investments.length,
      itemBuilder: (context, index) {
        final investment = investments[index];
        return Card(
          child: ListTile(
            title: Text(investment.name ?? investment.type ?? 'Investment'),
            subtitle: Text(investment.subtype ?? investment.type ?? ''),
            trailing: Text(
              formatMoney(investment.balance ?? 0, investment.currencyCode),
            ),
          ),
        );
      },
    );
  }
}

class _LoansTab extends StatelessWidget {
  const _LoansTab({required this.loans});

  final List<LoanSummary> loans;

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return const AppEmptyState(
        icon: Icons.account_balance_outlined,
        title: 'No loans synced yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        final installments = loan.installmentsTotal == null
            ? null
            : '${loan.installmentsPaid ?? 0}/${loan.installmentsTotal}';
        return Card(
          child: ListTile(
            title: Text(loan.type ?? 'Loan'),
            subtitle: Text(
              [
                if (loan.status != null) loan.status!,
                if (installments != null) '$installments installments',
              ].join(' · '),
            ),
            trailing: Text(
              formatMoney(loan.outstandingBalance ?? 0, loan.currencyCode),
            ),
          ),
        );
      },
    );
  }
}

class _BillsTab extends StatelessWidget {
  const _BillsTab({required this.bills});

  final List<CreditCardBillSummary> bills;

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return const AppEmptyState(
        icon: Icons.credit_card_outlined,
        title: 'No credit card bills synced yet',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final bill = bills[index];
        return Card(
          child: ListTile(
            title: Text(
              bill.dueDate == null
                  ? 'Bill'
                  : 'Due ${formatShortDate(bill.dueDate!)}',
            ),
            subtitle: Text(
              bill.minimumPayment == null
                  ? ''
                  : 'Minimum payment ${formatMoney(bill.minimumPayment!, bill.currencyCode)}',
            ),
            trailing: Text(
              formatMoney(bill.totalAmount ?? 0, bill.currencyCode),
            ),
          ),
        );
      },
    );
  }
}

class _BalanceHistoryTab extends StatelessWidget {
  const _BalanceHistoryTab({required this.points});

  final List<BalancePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AppEmptyState(
        icon: Icons.show_chart_outlined,
        title: 'No balance history yet',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: BalanceHistoryChart(
        data: BalanceHistoryChartData.fromBalancePoints(points),
      ),
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({required this.categories});

  final List<CategoryBreakdownItem> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const AppEmptyState(
        icon: Icons.pie_chart_outline,
        title: 'No categorized spending yet',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: CategoryBreakdownChart(
        data: CategoryBreakdownChartData.fromItems(categories),
      ),
    );
  }
}
