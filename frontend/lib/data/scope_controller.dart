import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/household_member.dart';

/// The six period presets from `design.md`'s Global Scope section (§4),
/// plus `custom` for an explicit user-picked range.
enum PeriodPreset { thisMonth, lastMonth, last3Months, thisYear, last12Months, custom }

/// Global period + member scope, shared across Início/Contas/Análises per
/// `design.md`'s effect table. One instance per household (constructed by
/// `HouseholdShell`, matching `AuthRepository`'s app-lifetime `ChangeNotifier`
/// pattern but scoped to a single household instead of the whole app).
///
/// Member selection persists across sessions (`shared_preferences`, keyed by
/// household); period selection deliberately does not — it always resets to
/// [PeriodPreset.thisMonth] on construction, per the spec's "resets to Este
/// mês on cold launch" rule.
class ScopeController extends ChangeNotifier {
  ScopeController({required this.householdId});

  final String householdId;

  PeriodPreset _preset = PeriodPreset.thisMonth;
  int _offset = 0;
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _comparePrevious = false;
  Set<String> _selectedMemberIds = {};
  bool _isLoaded = false;
  List<HouseholdMember> _members = const [];

  PeriodPreset get preset => _preset;
  bool get comparePrevious => _comparePrevious;

  /// Empty means "all members" — no filter applied.
  Set<String> get selectedMemberIds => _selectedMemberIds;
  bool get isLoaded => _isLoaded;

  /// The household's roster, `created_at`-ascending (the backend's own
  /// `list_members()` order) — the single source of truth for join-order
  /// indexing into [AppMemberColors.forIndex], shared by the member-chip
  /// row and any per-member chart so the same person gets the same color
  /// everywhere. Set once by [HouseholdShell] after it loads the roster;
  /// intentionally not fetched here — `ScopeController` doesn't own a
  /// `HouseholdRepository` reference, just holds whatever it's given.
  List<HouseholdMember> get members => _members;

  void setMembers(List<HouseholdMember> members) {
    _members = members;
    notifyListeners();
  }

  String get _prefsKey => 'scope_members_$householdId';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey);
    if (stored != null) {
      _selectedMemberIds = stored.toSet();
    }
    _isLoaded = true;
    notifyListeners();
  }

  void toggleMember(String id) {
    final next = {..._selectedMemberIds};
    if (!next.remove(id)) next.add(id);
    _selectedMemberIds = next;
    notifyListeners();
    unawaited(_persistMembers());
  }

  Future<void> _persistMembers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _selectedMemberIds.toList());
  }

  void setPreset(PeriodPreset preset) {
    _preset = preset;
    _offset = 0;
    if (preset != PeriodPreset.custom) {
      _customStart = null;
      _customEnd = null;
    }
    notifyListeners();
  }

  void setCustomRange(DateTime start, DateTime end) {
    _preset = PeriodPreset.custom;
    _offset = 0;
    _customStart = DateTime(start.year, start.month, start.day);
    _customEnd = DateTime(end.year, end.month, end.day);
    notifyListeners();
  }

  void setComparePrevious(bool value) {
    _comparePrevious = value;
    notifyListeners();
  }

  /// Steps the range back/forward by its own length, per `design.md`'s
  /// arrow rule ("Este mês" moves month to month, "Últimos 3 meses" jumps a
  /// quarter, a custom range shifts by its own day-length).
  void stepBack() => _step(-1);
  void stepForward() => _step(1);

  void _step(int direction) {
    if (_preset == PeriodPreset.custom) {
      final start = _customStart!;
      final end = _customEnd!;
      final spanDays = end.difference(start).inDays + 1;
      final shift = Duration(days: spanDays * direction);
      _customStart = start.add(shift);
      _customEnd = end.add(shift);
    } else {
      _offset += direction;
    }
    notifyListeners();
  }

  /// Resolves the current selection to a concrete `[start, end]` range —
  /// day-granularity, inclusive, suitable for `start_date`/`end_date` query
  /// params. `referenceNow` is injectable for tests; defaults to `DateTime.now()`.
  DateTimeRange resolveRange({DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    if (_preset == PeriodPreset.custom) {
      return DateTimeRange(start: _customStart!, end: _customEnd!);
    }

    switch (_preset) {
      case PeriodPreset.thisMonth:
        return _monthRange(now, _offset);
      case PeriodPreset.lastMonth:
        return _monthRange(now, _offset - 1);
      case PeriodPreset.last3Months:
        return _multiMonthRange(now, monthSpan: 3, windowOffset: _offset);
      case PeriodPreset.last12Months:
        return _multiMonthRange(now, monthSpan: 12, windowOffset: _offset);
      case PeriodPreset.thisYear:
        final year = now.year + _offset;
        return DateTimeRange(
          start: DateTime(year, 1, 1),
          end: DateTime(year, 12, 31),
        );
      case PeriodPreset.custom:
        throw StateError('custom range handled above');
    }
  }

  static DateTimeRange _monthRange(DateTime now, int monthOffset) {
    final anchor = DateTime(now.year, now.month + monthOffset, 1);
    final start = DateTime(anchor.year, anchor.month, 1);
    final end = DateTime(anchor.year, anchor.month + 1, 1).subtract(const Duration(days: 1));
    return DateTimeRange(start: start, end: end);
  }

  /// A rolling window of [monthSpan] months ending in the current month,
  /// shifted by [windowOffset] whole windows (i.e. `windowOffset * monthSpan`
  /// months) — used by both "last 3 months" and "last 12 months".
  static DateTimeRange _multiMonthRange(
    DateTime now, {
    required int monthSpan,
    required int windowOffset,
  }) {
    final endAnchor = DateTime(now.year, now.month + 1 + (windowOffset * monthSpan), 1)
        .subtract(const Duration(days: 1));
    final startAnchor = DateTime(endAnchor.year, endAnchor.month - (monthSpan - 1), 1);
    return DateTimeRange(start: startAnchor, end: endAnchor);
  }
}
