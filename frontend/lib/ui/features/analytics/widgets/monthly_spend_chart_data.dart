import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/extended_finance.dart';
import '../../../../data/models/household_member.dart';
import '../../../core/formatting/money.dart';

enum MonthlySpendChartMode { unstacked, stacked, rankedList }

/// Fixed plot height shared between this mapper and `MonthlySpendChart` so
/// the 4px-sliver fold below is computed against the exact same scale the
/// widget renders at — see `design.md`'s Chart Style Guide density
/// rulebook ("a segment that would draw under 4px goes into Outros" /
/// "same pixels-per-dollar across an entire chart").
const monthlySpendChartPlotHeightPx = 120.0;

const _outrosLabel = 'Outros';
const _minSegmentPx = 4.0;
const _minSeriesShare = 0.03;
const _maxNamedSeriesWithOutros = 3;

/// One member's (or Outros') slice of a month's bar, or a legend/ranked-list
/// row — same shape serves all three, per the existing `LegendSwatch`
/// (color + label) convention.
class MonthlySpendSegment {
  const MonthlySpendSegment({
    required this.label,
    required this.color,
    required this.value,
  });

  final String label;
  final Color color;
  final double value;
}

class MonthlySpendChartPoint {
  const MonthlySpendChartPoint({
    required this.monthLabel,
    required this.total,
    this.segments = const [],
  });

  final String monthLabel;
  final double total;

  /// Only populated in [MonthlySpendChartMode.stacked] — ordered bottom-up
  /// by member join order, Outros (if present) always last.
  final List<MonthlySpendSegment> segments;
}

class MonthlySpendChartData {
  const MonthlySpendChartData({
    required this.mode,
    this.points = const [],
    this.legend = const [],
    this.rankedTotals = const [],
  });

  /// Builds the real per-member chart per `design.md`'s Global Scope /
  /// density rulebook. `rows` is the raw `/spending-by-member` response;
  /// `members` is the household roster in join (`created_at`-ascending)
  /// order, from `ScopeController.members` — the same ordering the
  /// member-chip row uses for [AppMemberColors.forIndex], so a person gets
  /// the same color in the chart as in the chip row. `selectedMemberIds` is
  /// `ScopeController.selectedMemberIds` (empty means "all").
  factory MonthlySpendChartData.fromMemberSpend({
    required List<MemberMonthlySpend> rows,
    required List<HouseholdMember> members,
    required Set<String> selectedMemberIds,
  }) {
    final allIds = members.map((m) => m.id).toSet();
    final isAllSelected =
        selectedMemberIds.isEmpty || selectedMemberIds.length >= allIds.length;
    final effectiveIds = isAllSelected ? allIds : selectedMemberIds;

    // Rule ordering: "all selected" always wins, even when the household
    // has 5+ members and the filter was simply left untouched — this is
    // rule 1 of design.md's density rulebook taking precedence over rule 3,
    // not an accident of branch order.
    if (isAllSelected || effectiveIds.length <= 1) {
      return _unstackedFromRows(rows);
    }
    if (effectiveIds.length > 4) {
      return _rankedListFromRows(rows, members);
    }
    return _stackedFromRows(rows, members);
  }

  final MonthlySpendChartMode mode;
  final List<MonthlySpendChartPoint> points;

  /// Only populated in [MonthlySpendChartMode.stacked] — the chart's own
  /// legend row, already capped at 4 entries by construction.
  final List<MonthlySpendSegment> legend;

  /// Only populated in [MonthlySpendChartMode.rankedList] — member totals
  /// summed over the whole range, sorted descending.
  final List<MonthlySpendSegment> rankedTotals;

  bool get isEmpty =>
      mode == MonthlySpendChartMode.rankedList ? rankedTotals.isEmpty : points.isEmpty;

  static MonthlySpendChartData _unstackedFromRows(List<MemberMonthlySpend> rows) {
    final totals = <String, double>{};
    for (final row in rows) {
      totals[row.month] = (totals[row.month] ?? 0) + row.total;
    }
    final months = totals.keys.toList()..sort();
    return MonthlySpendChartData(
      mode: MonthlySpendChartMode.unstacked,
      points: [
        for (final month in months)
          MonthlySpendChartPoint(monthLabel: formatMonth(month), total: totals[month]!),
      ],
    );
  }

  static MonthlySpendChartData _rankedListFromRows(
    List<MemberMonthlySpend> rows,
    List<HouseholdMember> members,
  ) {
    final index = _memberIndex(members);
    final totals = <String?, double>{};
    for (final row in rows) {
      final key = index.containsKey(row.memberId) ? row.memberId : null;
      totals[key] = (totals[key] ?? 0) + row.total;
    }
    final ranked = [
      for (final entry in totals.entries)
        MonthlySpendSegment(
          label: _labelFor(entry.key, members),
          color: _colorFor(entry.key, index),
          value: entry.value,
        ),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return MonthlySpendChartData(mode: MonthlySpendChartMode.rankedList, rankedTotals: ranked);
  }

  static MonthlySpendChartData _stackedFromRows(
    List<MemberMonthlySpend> rows,
    List<HouseholdMember> members,
  ) {
    final index = _memberIndex(members);

    // Unknown members (removed since the transaction was recorded) fold
    // into Outros unconditionally, same as unattributed (null) rows — both
    // use `null` as the series key from here on.
    final byMonthAndKey = <String, Map<String?, double>>{};
    for (final row in rows) {
      final key = index.containsKey(row.memberId) ? row.memberId : null;
      final monthMap = byMonthAndKey.putIfAbsent(row.month, () => {});
      monthMap[key] = (monthMap[key] ?? 0) + row.total;
    }
    final months = byMonthAndKey.keys.toList()..sort();

    // Step 1: global per-series total across the whole range — computed
    // once for the whole chart (not per month) so a member doesn't appear
    // in some bars and not others, then used for both the 3% fold and the
    // legend cap below.
    final seriesTotals = <String?, double>{};
    var grandTotal = 0.0;
    for (final monthMap in byMonthAndKey.values) {
      for (final entry in monthMap.entries) {
        seriesTotals[entry.key] = (seriesTotals[entry.key] ?? 0) + entry.value;
        grandTotal += entry.value;
      }
    }

    // Step 2: 3%-of-whole-range fold. Outros (`null`) is never itself a
    // fold candidate — it's the catch-all, not a series.
    var structuralOutros = seriesTotals[null] ?? 0;
    final keptNamed = <String>[];
    for (final key in seriesTotals.keys.whereType<String>()) {
      final share = grandTotal <= 0 ? 0.0 : seriesTotals[key]! / grandTotal;
      if (share < _minSeriesShare) {
        structuralOutros += seriesTotals[key]!;
      } else {
        keptNamed.add(key);
      }
    }

    // Step 3: legend cap. If Outros is (or becomes) structurally non-empty
    // (unattributed rows, or a whole member folded below 3%), cap named
    // series at 3 — otherwise up to 4 selected members plus a non-empty
    // Outros row can reach 5 legend entries, busting the four-entry rule
    // even when no single member trips the 3% test on its own. This
    // decision uses the *structural* Outros total (pre-4px-fold, below) —
    // the per-month 4px fold is a rendering nicety, not a reason to cap an
    // otherwise-clean 4-named-member selection.
    keptNamed.sort((a, b) => seriesTotals[b]!.compareTo(seriesTotals[a]!));
    if (structuralOutros > 0 && keptNamed.length > _maxNamedSeriesWithOutros) {
      for (final key in keptNamed.skip(_maxNamedSeriesWithOutros)) {
        structuralOutros += seriesTotals[key]!;
      }
      keptNamed.removeRange(_maxNamedSeriesWithOutros, keptNamed.length);
    }

    // Final render order: named series by join order, Outros always last.
    keptNamed.sort((a, b) => index[a]!.compareTo(index[b]!));

    // Step 4: exact 4px-minimum fold, per month. `overallMaxMonthlyTotal`
    // is the tallest bar across the whole chart — every bar shares that
    // same scale ("same pixels-per-dollar across an entire chart"), so the
    // minimum-dollar threshold for a visible 4px segment is computed once,
    // not per month. This can introduce a non-zero Outros value in a
    // month even when `structuralOutros` was zero, so whether the chart
    // has an Outros series at all is only decided once every month's fold
    // is known (`anyOutros` below) — otherwise a 4px-folded value would
    // have nowhere to go in a month that started with no Outros bucket.
    final monthlyRawTotals = {
      for (final month in months)
        month: byMonthAndKey[month]!.values.fold<double>(0, (a, b) => a + b),
    };
    final overallMaxMonthlyTotal =
        monthlyRawTotals.values.fold<double>(0, (max, v) => v > max ? v : max);
    final pixelsPerDollar = overallMaxMonthlyTotal <= 0
        ? 0.0
        : monthlySpendChartPlotHeightPx / overallMaxMonthlyTotal;
    final minSegmentValue = pixelsPerDollar <= 0 ? 0.0 : _minSegmentPx / pixelsPerDollar;

    final namedValuesByMonth = <String, Map<String, double>>{};
    final outrosByMonth = <String, double>{};
    var anyOutros = structuralOutros > 0;
    for (final month in months) {
      final monthMap = byMonthAndKey[month]!;

      // Anything not in the final kept-named set (globally folded members,
      // unattributed, or unknown members) folds into this month's Outros —
      // its dollar value is added in, never dropped, so the bar's total
      // height still matches the true monthly total.
      var monthOutros = 0.0;
      for (final entry in monthMap.entries) {
        if (entry.key == null || !keptNamed.contains(entry.key)) {
          monthOutros += entry.value;
        }
      }

      final namedValues = <String, double>{};
      for (final key in keptNamed) {
        var value = monthMap[key] ?? 0;
        if (value > 0 && value < minSegmentValue) {
          monthOutros += value;
          value = 0;
        }
        namedValues[key] = value;
      }
      namedValuesByMonth[month] = namedValues;
      outrosByMonth[month] = monthOutros;
      if (monthOutros > 0) anyOutros = true;
    }

    // Pass 2: build the points and legend together from the same final
    // per-month values, so the legend's Outros total always matches what
    // the bars actually draw (including any 4px-fold contributions).
    final legendTotals = {for (final key in keptNamed) key: 0.0};
    var outrosLegendTotal = 0.0;
    final points = <MonthlySpendChartPoint>[];
    for (final month in months) {
      final namedValues = namedValuesByMonth[month]!;
      final segments = <MonthlySpendSegment>[];
      for (final key in keptNamed) {
        final value = namedValues[key]!;
        legendTotals[key] = legendTotals[key]! + value;
        segments.add(
          MonthlySpendSegment(label: _labelFor(key, members), color: _colorFor(key, index), value: value),
        );
      }
      if (anyOutros) {
        final value = outrosByMonth[month]!;
        outrosLegendTotal += value;
        segments.add(MonthlySpendSegment(label: _outrosLabel, color: AppMemberColors.outros, value: value));
      }
      points.add(
        MonthlySpendChartPoint(
          monthLabel: formatMonth(month),
          total: segments.fold<double>(0, (sum, s) => sum + s.value),
          segments: segments,
        ),
      );
    }

    final legend = [
      for (final key in keptNamed)
        MonthlySpendSegment(label: _labelFor(key, members), color: _colorFor(key, index), value: legendTotals[key]!),
      if (anyOutros)
        MonthlySpendSegment(label: _outrosLabel, color: AppMemberColors.outros, value: outrosLegendTotal),
    ];

    return MonthlySpendChartData(mode: MonthlySpendChartMode.stacked, points: points, legend: legend);
  }

  static Map<String, int> _memberIndex(List<HouseholdMember> members) {
    return {for (var i = 0; i < members.length; i++) members[i].id: i};
  }

  static String _labelFor(String? memberId, List<HouseholdMember> members) {
    if (memberId == null) return _outrosLabel;
    return members.firstWhere((m) => m.id == memberId).email;
  }

  static Color _colorFor(String? memberId, Map<String, int> index) {
    if (memberId == null) return AppMemberColors.outros;
    return AppMemberColors.forIndex(index[memberId]!);
  }
}
