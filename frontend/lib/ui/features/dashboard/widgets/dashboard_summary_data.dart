import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/dashboard.dart';
import '../../../../data/models/extended_finance.dart';
import '../../../../data/models/household_member.dart';

const _faturaWarningWindowDays = 7;

/// Início's hero numbers — `Gastos do mês`/`Entradas`/`Sobrou` — summed
/// across whatever `Dashboard.monthlyCashFlow` buckets the selected period
/// into (usually one row for the default "Este mês"; more for a longer
/// period, per `design.md`'s Global Scope — the label stays "Gastos do mês"
/// regardless, since the period pill above already states the active range).
class HeroSummary {
  const HeroSummary({required this.expenses, required this.income});

  factory HeroSummary.fromMonthlyCashFlow(List<MonthlyCashFlow> monthlyCashFlow) {
    var expenses = 0.0;
    var income = 0.0;
    for (final month in monthlyCashFlow) {
      expenses += month.expenses;
      income += month.income;
    }
    return HeroSummary(expenses: expenses, income: income);
  }

  final double expenses;
  final double income;
  double get sobrou => income - expenses;
}

/// `Limite disponível X de Y · N cartões` — summed across every
/// `type == 'CREDIT'` account currently in scope.
class CreditBlockSummary {
  const CreditBlockSummary({
    required this.availableTotal,
    required this.limitTotal,
    required this.cardCount,
  });

  factory CreditBlockSummary.fromAccounts(List<AccountSummary> accounts) {
    var availableTotal = 0.0;
    var limitTotal = 0.0;
    var cardCount = 0;
    for (final account in accounts) {
      if (account.type != 'CREDIT') continue;
      cardCount++;
      availableTotal += account.availableCreditLimit ?? 0;
      limitTotal += account.creditLimit ?? 0;
    }
    return CreditBlockSummary(
      availableTotal: availableTotal,
      limitTotal: limitTotal,
      cardCount: cardCount,
    );
  }

  final double availableTotal;
  final double limitTotal;
  final int cardCount;
  bool get hasCards => cardCount > 0;
}

/// Hero's `Comprometido` figure — the sum of every card's current fatura
/// (see [currentBillsByAccount]'s doc comment for what "current" means
/// here) across the whole household, independent of the selected period:
/// this is a snapshot of money already owed, not a period sum.
double committedTotal(List<CreditCardBillSummary> bills, {DateTime? referenceNow}) {
  final currentBills = currentBillsByAccount(bills, referenceNow: referenceNow);
  return currentBills.values.fold<double>(0, (sum, bill) => sum + (bill.totalAmount ?? 0));
}

/// A single card's current fatura, resolved from its bill list — see
/// [currentBillsByAccount]'s doc comment for the "soonest upcoming bill"
/// heuristic and its known limitation.
class FaturaWarning {
  const FaturaWarning({required this.accountName, required this.bill, required this.daysUntilDue});

  final String accountName;
  final CreditCardBillSummary bill;
  final int daysUntilDue;
}

/// Picks, per card `accountId`, the bill with the soonest `dueDate` that
/// hasn't passed yet — `CreditCardBillSummary` has no "paid" flag, so this
/// can't distinguish an already-settled bill from a genuinely open one;
/// treating "soonest future due date" as "current" is a documented
/// simplification, not a guarantee.
Map<String, CreditCardBillSummary> currentBillsByAccount(
  List<CreditCardBillSummary> bills, {
  DateTime? referenceNow,
}) {
  final now = referenceNow ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final result = <String, CreditCardBillSummary>{};
  for (final bill in bills) {
    final dueDate = bill.dueDate;
    if (dueDate == null || dueDate.isBefore(today)) continue;
    final existing = result[bill.accountId];
    if (existing == null || (existing.dueDate != null && dueDate.isBefore(existing.dueDate!))) {
      result[bill.accountId] = bill;
    }
  }
  return result;
}

/// The single soonest-due fatura across every card in scope, if it's due
/// within [_faturaWarningWindowDays] — Início's fatura-due warning row.
FaturaWarning? pickFaturaWarning(
  List<CreditCardBillSummary> bills,
  List<AccountSummary> accounts, {
  DateTime? referenceNow,
}) {
  final now = referenceNow ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final currentBills = currentBillsByAccount(bills, referenceNow: now);
  if (currentBills.isEmpty) return null;

  final accountNames = {for (final a in accounts) a.id: a.name ?? 'Conta'};

  MapEntry<String, CreditCardBillSummary>? soonest;
  for (final entry in currentBills.entries) {
    final current = soonest;
    if (current == null || entry.value.dueDate!.isBefore(current.value.dueDate!)) {
      soonest = entry;
    }
  }
  final winner = soonest!;
  final bill = winner.value;
  final daysUntilDue = bill.dueDate!.difference(today).inDays;
  if (daysUntilDue > _faturaWarningWindowDays) return null;

  return FaturaWarning(
    accountName: accountNames[winner.key] ?? 'Cartão',
    bill: bill,
    daysUntilDue: daysUntilDue,
  );
}

/// One row of Início's "Por membro" section — member label/color resolved
/// the same way every other member-colored list in the app does (join-order
/// index into [AppMemberColors]), summed over whatever range the caller
/// already scoped `rows` to. No deviation-from-average sub-line — that's
/// separate, backend-gated work (see `design.md`'s Alerts section).
class MemberSpendRow {
  const MemberSpendRow({required this.label, required this.color, required this.total});

  final String label;
  final Color color;
  final double total;
}

List<MemberSpendRow> memberSpendRows(
  List<MemberMonthlySpend> rows,
  List<HouseholdMember> members,
) {
  final totals = <String, double>{};
  for (final row in rows) {
    final memberId = row.memberId;
    if (memberId == null) continue;
    totals[memberId] = (totals[memberId] ?? 0) + row.total;
  }
  return [
    for (var i = 0; i < members.length; i++)
      if (totals.containsKey(members[i].id))
        MemberSpendRow(
          label: members[i].email,
          color: AppMemberColors.forIndex(i),
          total: totals[members[i].id]!,
        ),
  ];
}
