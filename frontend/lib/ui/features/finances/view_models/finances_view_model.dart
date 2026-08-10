import 'package:flutter/foundation.dart';

import '../../../../data/models/extended_finance.dart';
import '../../../../data/repositories/extended_finance_repository.dart';
import '../../../../data/services/api_exception.dart';

class FinancesViewModel extends ChangeNotifier {
  FinancesViewModel({
    required ExtendedFinanceRepository financeRepository,
    required String householdId,
  }) : _financeRepository = financeRepository,
       _householdId = householdId;

  final ExtendedFinanceRepository _financeRepository;
  final String _householdId;

  List<InvestmentSummary> _investments = const [];
  List<LoanSummary> _loans = const [];
  List<CreditCardBillSummary> _bills = const [];
  List<BalancePoint> _balanceHistory = const [];
  List<CategoryBreakdownItem> _categories = const [];
  List<MemberMonthlySpend> _spendingByMember = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<InvestmentSummary> get investments => _investments;
  List<LoanSummary> get loans => _loans;
  List<CreditCardBillSummary> get bills => _bills;
  List<BalancePoint> get balanceHistory => _balanceHistory;
  List<CategoryBreakdownItem> get categories => _categories;
  List<MemberMonthlySpend> get spendingByMember => _spendingByMember;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({
    DateTime? startDate,
    DateTime? endDate,
    Set<String>? memberIds,
    bool comparePrevious = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _financeRepository.getInvestments(_householdId, memberIds: memberIds),
        _financeRepository.getLoans(_householdId, memberIds: memberIds),
        _financeRepository.getCreditCardBills(_householdId, memberIds: memberIds),
        _financeRepository.getBalanceHistory(_householdId, memberIds: memberIds),
        _financeRepository.getCategoryBreakdown(
          _householdId,
          startDate: startDate,
          endDate: endDate,
          memberIds: memberIds,
          comparePrevious: comparePrevious,
        ),
        // Only meaningful over a concrete period — the old no-args caller
        // (`finances_view.dart`) never sets one, so skip the call entirely
        // rather than have the backend silently default it.
        if (startDate != null && endDate != null)
          _financeRepository.getSpendingByMember(
            _householdId,
            startDate: startDate,
            endDate: endDate,
            memberIds: memberIds,
          ),
      ]);
      _investments = results[0] as List<InvestmentSummary>;
      _loans = results[1] as List<LoanSummary>;
      _bills = results[2] as List<CreditCardBillSummary>;
      _balanceHistory = results[3] as List<BalancePoint>;
      _categories = results[4] as List<CategoryBreakdownItem>;
      _spendingByMember = results.length > 5
          ? results[5] as List<MemberMonthlySpend>
          : const [];
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Não foi possível carregar suas finanças.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
