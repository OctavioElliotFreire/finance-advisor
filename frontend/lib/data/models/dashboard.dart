class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.subtype,
    required this.balance,
    required this.currencyCode,
    this.creditLimit,
    this.availableCreditLimit,
    this.connectionStatus,
    this.ownerMemberId,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    return AccountSummary(
      id: json['id'] as String,
      name: json['name'] as String?,
      type: json['type'] as String?,
      subtype: json['subtype'] as String?,
      balance: (json['balance'] as num?)?.toDouble(),
      currencyCode: json['currency_code'] as String,
      creditLimit: (json['credit_limit'] as num?)?.toDouble(),
      availableCreditLimit: (json['available_credit_limit'] as num?)?.toDouble(),
      connectionStatus: json['connection_status'] as String?,
      ownerMemberId: json['owner_member_id'] as String?,
    );
  }

  final String id;
  final String? name;
  final String? type;
  final String? subtype;
  final double? balance;
  final String currencyCode;
  final double? creditLimit;
  final double? availableCreditLimit;
  final String? connectionStatus;
  final String? ownerMemberId;
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
  const SyncStatus({
    required this.status,
    required this.updatedAt,
    this.syncedConnections = 0,
    this.totalConnections = 0,
  });

  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      status: json['status'] as String?,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      syncedConnections: (json['synced_connections'] as num?)?.toInt() ?? 0,
      totalConnections: (json['total_connections'] as num?)?.toInt() ?? 0,
    );
  }

  final String? status;
  final DateTime? updatedAt;
  final int syncedConnections;
  final int totalConnections;
}

class Dashboard {
  const Dashboard({
    required this.householdName,
    required this.accounts,
    required this.totalBalance,
    required this.recentTransactions,
    required this.monthlyCashFlow,
    required this.syncStatus,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    return Dashboard(
      householdName: json['household_name'] as String,
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

  final String householdName;
  final List<AccountSummary> accounts;
  final double totalBalance;
  final List<TransactionSummary> recentTransactions;
  final List<MonthlyCashFlow> monthlyCashFlow;
  final SyncStatus syncStatus;
}
