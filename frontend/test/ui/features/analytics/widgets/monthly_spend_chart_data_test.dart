import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/extended_finance.dart';
import 'package:frontend/data/models/household_member.dart';
import 'package:frontend/ui/features/analytics/widgets/monthly_spend_chart_data.dart';

HouseholdMember _member(String id, String email) {
  return HouseholdMember(
    id: id,
    appUserId: 'au-$id',
    email: email,
    role: 'member',
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('mode selection', () {
    final members = [_member('a', 'a@x.com'), _member('b', 'b@x.com'), _member('c', 'c@x.com')];
    final rows = [
      const MemberMonthlySpend(month: '2026-07', memberId: 'a', total: 100),
      const MemberMonthlySpend(month: '2026-07', memberId: 'b', total: 200),
      const MemberMonthlySpend(month: '2026-07', memberId: 'c', total: 300),
    ];

    test('empty selection (all) is unstacked', () {
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: rows,
        members: members,
        selectedMemberIds: {},
      );
      expect(data.mode, MonthlySpendChartMode.unstacked);
      expect(data.points.single.total, 600);
    });

    test('every member explicitly checked is still unstacked, not stacked', () {
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: rows,
        members: members,
        selectedMemberIds: {'a', 'b', 'c'},
      );
      expect(data.mode, MonthlySpendChartMode.unstacked);
    });

    test('a single selected member is unstacked', () {
      // In production `rows` is already backend-filtered to the selected
      // member(s) via the `member_ids` query param — only 'a' rows here,
      // matching that real shape.
      final onlyA = [const MemberMonthlySpend(month: '2026-07', memberId: 'a', total: 100)];
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: onlyA,
        members: members,
        selectedMemberIds: {'a'},
      );
      expect(data.mode, MonthlySpendChartMode.unstacked);
      expect(data.points.single.total, 100);
    });

    test('2-4 explicitly selected members (subset of a larger household) stacks', () {
      final fourMembers = [...members, _member('d', 'd@x.com')];
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: rows,
        members: fourMembers,
        selectedMemberIds: {'a', 'b'},
      );
      expect(data.mode, MonthlySpendChartMode.stacked);
    });

    test('5+ explicit subset refuses to stack and returns a ranked list', () {
      // 6 total members, only 5 selected — a genuine subset, not "all".
      final sixMembers = [
        for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) _member(id, '$id@x.com'),
      ];
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: rows,
        members: sixMembers,
        selectedMemberIds: {'a', 'b', 'c', 'd', 'e'},
      );
      expect(data.mode, MonthlySpendChartMode.rankedList);
    });

    test('"all" wins over the 5+ ranked-list rule when the household itself has 5+ members', () {
      final fiveMembers = [
        for (final id in ['a', 'b', 'c', 'd', 'e']) _member(id, '$id@x.com'),
      ];
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: rows,
        members: fiveMembers,
        selectedMemberIds: {}, // nothing checked = everyone, even though that's 5 people
      );
      expect(data.mode, MonthlySpendChartMode.unstacked);
    });
  });

  group('ranked list', () {
    test('sums each member over the whole range and sorts descending', () {
      final members = [_member('a', 'a@x.com'), _member('b', 'b@x.com')];
      final rows = [
        const MemberMonthlySpend(month: '2026-06', memberId: 'a', total: 50),
        const MemberMonthlySpend(month: '2026-07', memberId: 'a', total: 50),
        const MemberMonthlySpend(month: '2026-06', memberId: 'b', total: 500),
      ];
      // 6 total members, only 5 selected — a genuine subset, not "all".
      final sixMembers = [
        ...members,
        for (final id in ['c', 'd', 'e', 'f']) _member(id, '$id@x.com'),
      ];
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: rows,
        members: sixMembers,
        selectedMemberIds: {'a', 'b', 'c', 'd', 'e'},
      );
      expect(data.mode, MonthlySpendChartMode.rankedList);
      expect(data.rankedTotals.map((e) => e.label), ['b@x.com', 'a@x.com']);
      expect(data.rankedTotals[0].value, 500);
      expect(data.rankedTotals[1].value, 100);
    });
  });

  group('stacked density rules', () {
    test('a member under 3% of the whole-range total folds into Outros', () {
      final members = [
        _member('a', 'a@x.com'),
        _member('b', 'b@x.com'),
        _member('c', 'c@x.com'),
        _member('d', 'd@x.com'),
      ];
      // a: 4850, b: 100 -> b's share is 100/4950 ≈ 2.02%, under the 3%
      // line, so it folds into Outros even though it's the only other
      // selected member (d isn't selected here at all).
      final rows = [
        const MemberMonthlySpend(month: '2026-07', memberId: 'a', total: 4850),
        const MemberMonthlySpend(month: '2026-07', memberId: 'b', total: 100),
      ];
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: rows,
        members: members,
        selectedMemberIds: {'a', 'b'},
      );
      expect(data.mode, MonthlySpendChartMode.stacked);
      final legendLabels = data.legend.map((e) => e.label).toList();
      expect(legendLabels, ['a@x.com', 'Outros']);
      expect(data.legend.firstWhere((e) => e.label == 'Outros').value, 100);
    });

    test('unattributed (null member_id) rows always bucket into Outros', () {
      final members = [_member('a', 'a@x.com'), _member('b', 'b@x.com')];
      final threeMembers = [...members, _member('c', 'c@x.com')];
      final rows = [
        const MemberMonthlySpend(month: '2026-07', memberId: 'a', total: 100),
        const MemberMonthlySpend(month: '2026-07', memberId: 'b', total: 100),
        const MemberMonthlySpend(month: '2026-07', memberId: null, total: 50),
      ];
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: rows,
        members: threeMembers,
        selectedMemberIds: {'a', 'b'},
      );
      expect(data.mode, MonthlySpendChartMode.stacked);
      expect(data.legend.map((e) => e.label), ['a@x.com', 'b@x.com', 'Outros']);
      expect(data.legend.last.value, 50);
    });

    test('legend caps named series at 3 when Outros is structurally non-empty', () {
      // 5 total members — {a,b,c,d} selected is a genuine subset (e is
      // not selected), not "all".
      final members = [
        _member('a', 'a@x.com'),
        _member('b', 'b@x.com'),
        _member('c', 'c@x.com'),
        _member('d', 'd@x.com'),
        _member('e', 'e@x.com'),
      ];
      // All four selected members well above 3%, but a real unattributed
      // row makes Outros non-empty — so the smallest named member (d, 100)
      // must fold in too, capping legend at 3 named + Outros = 4 entries.
      final rows = [
        const MemberMonthlySpend(month: '2026-07', memberId: 'a', total: 1000),
        const MemberMonthlySpend(month: '2026-07', memberId: 'b', total: 800),
        const MemberMonthlySpend(month: '2026-07', memberId: 'c', total: 600),
        const MemberMonthlySpend(month: '2026-07', memberId: 'd', total: 100),
        const MemberMonthlySpend(month: '2026-07', memberId: null, total: 50),
      ];
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: rows,
        members: members,
        selectedMemberIds: {'a', 'b', 'c', 'd'},
      );
      expect(data.mode, MonthlySpendChartMode.stacked);
      expect(data.legend.length, 4);
      final labels = data.legend.map((e) => e.label).toList();
      expect(labels, ['a@x.com', 'b@x.com', 'c@x.com', 'Outros']);
      // Outros = unattributed 50 + folded d's 100.
      expect(data.legend.last.value, 150);
    });

    test('a segment under 4px folds into that month only, and the value is added to Outros, never dropped', () {
      final members = [_member('a', 'a@x.com'), _member('b', 'b@x.com')];
      final fourMembers = [...members, _member('c', 'c@x.com'), _member('d', 'd@x.com')];
      // June: a=1000, b=900, unattributed=100 (total 2000, the chart max).
      // July: a=50 (tiny relative to the 2950 max -> folds), b=2900.
      // minSegmentValue = plotHeight(120)/ (120/2950) ... i.e. overallMax=2950,
      // pixelsPerDollar = 120/2950, minSegmentValue = 4 / pixelsPerDollar
      //   = 4 * 2950 / 120 ≈ 98.3 — July's a=50 is under that, June's a=1000 is not.
      final rows = [
        const MemberMonthlySpend(month: '2026-06', memberId: 'a', total: 1000),
        const MemberMonthlySpend(month: '2026-06', memberId: 'b', total: 900),
        const MemberMonthlySpend(month: '2026-06', memberId: null, total: 100),
        const MemberMonthlySpend(month: '2026-07', memberId: 'a', total: 50),
        const MemberMonthlySpend(month: '2026-07', memberId: 'b', total: 2900),
      ];
      final data = MonthlySpendChartData.fromMemberSpend(
        rows: rows,
        members: fourMembers,
        selectedMemberIds: {'a', 'b'},
      );

      expect(data.mode, MonthlySpendChartMode.stacked);
      expect(data.points, hasLength(2));

      final june = data.points[0];
      final july = data.points[1];

      // June: a's 1000 is well above the threshold, stays visible.
      expect(june.segments.map((s) => s.label), ['a@x.com', 'b@x.com', 'Outros']);
      expect(june.segments[0].value, 1000);
      expect(june.segments[1].value, 900);
      expect(june.segments[2].value, 100);
      expect(june.total, 2000);

      // July: a's 50 is under the 4px-equivalent threshold, folds into
      // July's Outros (which starts at 0 structurally) rather than vanishing.
      expect(july.segments.map((s) => s.label), ['a@x.com', 'b@x.com', 'Outros']);
      expect(july.segments[0].value, 0);
      expect(july.segments[1].value, 2900);
      expect(july.segments[2].value, 50);
      expect(july.total, 2950);

      // Legend reflects the actual post-fold totals drawn, not the
      // pre-4px-fold per-member sums (a would otherwise show 1050, not 1000).
      final legendByLabel = {for (final e in data.legend) e.label: e.value};
      expect(legendByLabel['a@x.com'], 1000);
      expect(legendByLabel['b@x.com'], 3800);
      expect(legendByLabel['Outros'], 150);
    });
  });

  test('isEmpty is true when there is nothing to render', () {
    final data = MonthlySpendChartData.fromMemberSpend(
      rows: const [],
      members: const [],
      selectedMemberIds: const {},
    );
    expect(data.isEmpty, isTrue);
  });
}
