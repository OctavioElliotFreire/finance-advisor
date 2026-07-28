class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.subtype,
    required this.balance,
    required this.currencyCode,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    return AccountSummary(
      id: json['id'] as String,
      name: json['name'] as String?,
      type: json['type'] as String?,
      subtype: json['subtype'] as String?,
      balance: (json['balance'] as num?)?.toDouble(),
      currencyCode: json['currency_code'] as String,
    );
  }

  final String id;
  final String? name;
  final String? type;
  final String? subtype;
  final double? balance;
  final String currencyCode;
}

class TransactionSummary {
  const TransactionSummary({
    required this.id,
    required this.accountName,
    required this.description,
    required this.amount,
    required this.currencyCode,
    required this.transactionDate,
    required this.category,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      id: json['id'] as String,
      accountName: json['account_name'] as String?,
      description: json['description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currency_code'] as String,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      category: json['category'] as String?,
    );
  }

  final String id;
  final String? accountName;
  final String? description;
  final double amount;
  final String currencyCode;
  final DateTime transactionDate;
  final String? category;
}

class MonthlyCashFlow {
  const MonthlyCashFlow({
    required this.month,
    required this.income,
    required this.expenses,
    required this.net,
  });

  factory MonthlyCashFlow.fromJson(Map<String, dynamic> json) {
    return MonthlyCashFlow(
      month: json['month'] as String,
      income: (json['income'] as num).toDouble(),
      expenses: (json['expenses'] as num).toDouble(),
      net: (json['net'] as num).toDouble(),
    );
  }

  final String month;
  final double income;
  final double expenses;
  final double net;
}

class SyncStatus {
  const SyncStatus({required this.status, required this.updatedAt});

  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      status: json['status'] as String?,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  final String? status;
  final DateTime? updatedAt;
}

class Dashboard {
  const Dashboard({
    required this.accounts,
    required this.totalBalance,
    required this.recentTransactions,
    required this.monthlyCashFlow,
    required this.syncStatus,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    return Dashboard(
      accounts: (json['accounts'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(AccountSummary.fromJson)
          .toList(),
      totalBalance: (json['total_balance'] as num).toDouble(),
      recentTransactions: (json['recent_transactions'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(TransactionSummary.fromJson)
          .toList(),
      monthlyCashFlow: (json['monthly_cash_flow'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(MonthlyCashFlow.fromJson)
          .toList(),
      syncStatus: SyncStatus.fromJson(
        json['sync_status'] as Map<String, dynamic>,
      ),
    );
  }

  final List<AccountSummary> accounts;
  final double totalBalance;
  final List<TransactionSummary> recentTransactions;
  final List<MonthlyCashFlow> monthlyCashFlow;
  final SyncStatus syncStatus;
}
