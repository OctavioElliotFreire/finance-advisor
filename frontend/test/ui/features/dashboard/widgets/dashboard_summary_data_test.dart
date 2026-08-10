import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/dashboard.dart';
import 'package:frontend/data/models/extended_finance.dart';
import 'package:frontend/data/models/household_member.dart';
import 'package:frontend/ui/features/dashboard/widgets/dashboard_summary_data.dart';

HouseholdMember _member(String id, String email) {
  return HouseholdMember(
    id: id,
    appUserId: 'au-$id',
    email: email,
    role: 'member',
    createdAt: DateTime(2026, 1, 1),
  );
}

AccountSummary _account({
  required String id,
  String type = 'BANK',
  double? balance,
  double? creditLimit,
  double? availableCreditLimit,
  String? name,
}) {
  return AccountSummary(
    id: id,
    name: name ?? id,
    type: type,
    subtype: null,
    balance: balance,
    currencyCode: 'BRL',
    creditLimit: creditLimit,
    availableCreditLimit: availableCreditLimit,
  );
}

CreditCardBillSummary _bill({
  required String id,
  required String accountId,
  DateTime? dueDate,
  DateTime? closingDate,
  double? totalAmount,
}) {
  return CreditCardBillSummary(
    id: id,
    accountId: accountId,
    dueDate: dueDate,
    closingDate: closingDate,
    totalAmount: totalAmount,
    minimumPayment: null,
    currencyCode: 'BRL',
  );
}

void main() {
  group('HeroSummary', () {
    test('sums expenses and income across every bucketed month', () {
      final hero = HeroSummary.fromMonthlyCashFlow(const [
        MonthlyCashFlow(month: '2026-07', income: 5000, expenses: 3200, net: 1800),
        MonthlyCashFlow(month: '2026-08', income: 1000, expenses: 800, net: 200),
      ]);
      expect(hero.expenses, 4000);
      expect(hero.income, 6000);
      expect(hero.sobrou, 2000);
    });

    test('empty input yields zeros', () {
      final hero = HeroSummary.fromMonthlyCashFlow(const []);
      expect(hero.expenses, 0);
      expect(hero.income, 0);
      expect(hero.sobrou, 0);
    });
  });

  group('CreditBlockSummary', () {
    test('sums only CREDIT-type accounts, ignoring bank accounts', () {
      final credit = CreditBlockSummary.fromAccounts([
        _account(id: 'checking', type: 'BANK', balance: 1000),
        _account(id: 'card-a', type: 'CREDIT', creditLimit: 5000, availableCreditLimit: 3000),
        _account(id: 'card-b', type: 'CREDIT', creditLimit: 10000, availableCreditLimit: 8000),
      ]);
      expect(credit.cardCount, 2);
      expect(credit.limitTotal, 15000);
      expect(credit.availableTotal, 11000);
      expect(credit.hasCards, isTrue);
    });

    test('no credit accounts yields hasCards false', () {
      final credit = CreditBlockSummary.fromAccounts([
        _account(id: 'checking', type: 'BANK', balance: 1000),
      ]);
      expect(credit.hasCards, isFalse);
      expect(credit.cardCount, 0);
    });
  });

  group('currentBillsByAccount', () {
    final now = DateTime(2026, 8, 10);

    test('picks the soonest future-due bill per account', () {
      final bills = [
        _bill(id: 'b1', accountId: 'card-a', dueDate: DateTime(2026, 9, 5)),
        _bill(id: 'b2', accountId: 'card-a', dueDate: DateTime(2026, 8, 15)),
      ];
      final result = currentBillsByAccount(bills, referenceNow: now);
      expect(result['card-a']!.id, 'b2');
    });

    test('excludes bills whose due date has already passed', () {
      final bills = [
        _bill(id: 'past', accountId: 'card-a', dueDate: DateTime(2026, 7, 1)),
      ];
      final result = currentBillsByAccount(bills, referenceNow: now);
      expect(result.containsKey('card-a'), isFalse);
    });

    test('a bill with no due date is ignored', () {
      final bills = [_bill(id: 'nodate', accountId: 'card-a')];
      final result = currentBillsByAccount(bills, referenceNow: now);
      expect(result, isEmpty);
    });
  });

  group('committedTotal', () {
    final now = DateTime(2026, 8, 10);

    test('sums the current bill across every card', () {
      final bills = [
        _bill(id: 'b1', accountId: 'card-a', dueDate: DateTime(2026, 8, 20), totalAmount: 1000),
        _bill(id: 'b2', accountId: 'card-b', dueDate: DateTime(2026, 9, 1), totalAmount: 500),
      ];
      expect(committedTotal(bills, referenceNow: now), 1500);
    });

    test('excludes already-passed bills and bills with no due date', () {
      final bills = [
        _bill(id: 'past', accountId: 'card-a', dueDate: DateTime(2026, 7, 1), totalAmount: 999),
        _bill(id: 'nodate', accountId: 'card-b', totalAmount: 999),
      ];
      expect(committedTotal(bills, referenceNow: now), 0);
    });

    test('no bills at all yields zero', () {
      expect(committedTotal(const [], referenceNow: now), 0);
    });
  });

  group('pickFaturaWarning', () {
    final now = DateTime(2026, 8, 10);
    final accounts = [_account(id: 'card-a', type: 'CREDIT', name: 'C6')];

    test('returns the soonest bill across all cards when due within the window', () {
      final bills = [_bill(id: 'b1', accountId: 'card-a', dueDate: DateTime(2026, 8, 13), totalAmount: 5760)];
      final warning = pickFaturaWarning(bills, accounts, referenceNow: now);
      expect(warning, isNotNull);
      expect(warning!.accountName, 'C6');
      expect(warning.daysUntilDue, 3);
      expect(warning.bill.totalAmount, 5760);
    });

    test('returns null when the soonest bill is beyond the warning window', () {
      final bills = [_bill(id: 'b1', accountId: 'card-a', dueDate: DateTime(2026, 9, 1))];
      final warning = pickFaturaWarning(bills, accounts, referenceNow: now);
      expect(warning, isNull);
    });

    test('returns null when there are no bills at all', () {
      final warning = pickFaturaWarning(const [], accounts, referenceNow: now);
      expect(warning, isNull);
    });
  });

  group('memberSpendRows', () {
    test('sums each member and orders by join order, skipping members with no spend', () {
      final members = [_member('a', 'a@x.com'), _member('b', 'b@x.com'), _member('c', 'c@x.com')];
      final rows = [
        const MemberMonthlySpend(month: '2026-08', memberId: 'b', total: 200),
        const MemberMonthlySpend(month: '2026-08', memberId: 'a', total: 100),
      ];
      final result = memberSpendRows(rows, members);
      expect(result.map((r) => r.label), ['a@x.com', 'b@x.com']);
      expect(result[0].total, 100);
      expect(result[1].total, 200);
    });

    test('sums a member across multiple months', () {
      final members = [_member('a', 'a@x.com')];
      final rows = [
        const MemberMonthlySpend(month: '2026-07', memberId: 'a', total: 50),
        const MemberMonthlySpend(month: '2026-08', memberId: 'a', total: 75),
      ];
      final result = memberSpendRows(rows, members);
      expect(result.single.total, 125);
    });

    test('unattributed (null member_id) rows are excluded, not shown as a row', () {
      final members = [_member('a', 'a@x.com')];
      final rows = [const MemberMonthlySpend(month: '2026-08', memberId: null, total: 999)];
      final result = memberSpendRows(rows, members);
      expect(result, isEmpty);
    });
  });
}
