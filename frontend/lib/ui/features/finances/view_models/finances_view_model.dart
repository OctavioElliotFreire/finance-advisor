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
  bool _isLoading = false;
  String? _errorMessage;

  List<InvestmentSummary> get investments => _investments;
  List<LoanSummary> get loans => _loans;
  List<CreditCardBillSummary> get bills => _bills;
  List<BalancePoint> get balanceHistory => _balanceHistory;
  List<CategoryBreakdownItem> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _financeRepository.getInvestments(_householdId),
        _financeRepository.getLoans(_householdId),
        _financeRepository.getCreditCardBills(_householdId),
        _financeRepository.getBalanceHistory(_householdId),
        _financeRepository.getCategoryBreakdown(_householdId),
      ]);
      _investments = results[0] as List<InvestmentSummary>;
      _loans = results[1] as List<LoanSummary>;
      _bills = results[2] as List<CreditCardBillSummary>;
      _balanceHistory = results[3] as List<BalancePoint>;
      _categories = results[4] as List<CategoryBreakdownItem>;
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
