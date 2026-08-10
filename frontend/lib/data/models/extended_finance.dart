class CreditCardBillSummary {
  const CreditCardBillSummary({
    required this.id,
    required this.accountId,
    required this.dueDate,
    required this.closingDate,
    required this.totalAmount,
    required this.minimumPayment,
    required this.currencyCode,
  });

  factory CreditCardBillSummary.fromJson(Map<String, dynamic> json) {
    return CreditCardBillSummary(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      closingDate: json['closing_date'] == null
          ? null
          : DateTime.parse(json['closing_date'] as String),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      minimumPayment: (json['minimum_payment'] as num?)?.toDouble(),
      currencyCode: json['currency_code'] as String,
    );
  }

  final String id;
  final String accountId;
  final DateTime? dueDate;
  final DateTime? closingDate;
  final double? totalAmount;
  final double? minimumPayment;
  final String currencyCode;
}

class InvestmentSummary {
  const InvestmentSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.subtype,
    required this.balance,
    required this.value,
    required this.quantity,
    required this.currencyCode,
    required this.investmentDate,
  });

  factory InvestmentSummary.fromJson(Map<String, dynamic> json) {
    return InvestmentSummary(
      id: json['id'] as String,
      name: json['name'] as String?,
      type: json['type'] as String?,
      subtype: json['subtype'] as String?,
      balance: (json['balance'] as num?)?.toDouble(),
      value: (json['value'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toDouble(),
      currencyCode: json['currency_code'] as String,
      investmentDate: json['investment_date'] == null
          ? null
          : DateTime.parse(json['investment_date'] as String),
    );
  }

  final String id;
  final String? name;
  final String? type;
  final String? subtype;
  final double? balance;
  final double? value;
  final double? quantity;
  final String currencyCode;
  final DateTime? investmentDate;
}

class LoanSummary {
  const LoanSummary({
    required this.id,
    required this.type,
    required this.status,
    required this.contractAmount,
    required this.outstandingBalance,
    required this.installmentAmount,
    required this.installmentsTotal,
    required this.installmentsPaid,
    required this.dueDate,
    required this.interestRate,
    required this.currencyCode,
  });

  factory LoanSummary.fromJson(Map<String, dynamic> json) {
    return LoanSummary(
      id: json['id'] as String,
      type: json['type'] as String?,
      status: json['status'] as String?,
      contractAmount: (json['contract_amount'] as num?)?.toDouble(),
      outstandingBalance: (json['outstanding_balance'] as num?)?.toDouble(),
      installmentAmount: (json['installment_amount'] as num?)?.toDouble(),
      installmentsTotal: json['installments_total'] as int?,
      installmentsPaid: json['installments_paid'] as int?,
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
      interestRate: (json['interest_rate'] as num?)?.toDouble(),
      currencyCode: json['currency_code'] as String,
    );
  }

  final String id;
  final String? type;
  final String? status;
  final double? contractAmount;
  final double? outstandingBalance;
  final double? installmentAmount;
  final int? installmentsTotal;
  final int? installmentsPaid;
  final DateTime? dueDate;
  final double? interestRate;
  final String currencyCode;
}

class BalancePoint {
  const BalancePoint({required this.snapshotDate, required this.totalBalance});

  factory BalancePoint.fromJson(Map<String, dynamic> json) {
    return BalancePoint(
      snapshotDate: DateTime.parse(json['snapshot_date'] as String),
      totalBalance: (json['total_balance'] as num).toDouble(),
    );
  }

  final DateTime snapshotDate;
  final double totalBalance;
}

class CategoryBreakdownItem {
  const CategoryBreakdownItem({
    required this.category,
    required this.total,
    this.previousTotal,
  });

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdownItem(
      category: json['category'] as String?,
      total: (json['total'] as num).toDouble(),
      previousTotal: (json['previous_total'] as num?)?.toDouble(),
    );
  }

  final String? category;
  final double total;
  final double? previousTotal;
}
