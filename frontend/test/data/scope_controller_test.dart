import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/data/scope_controller.dart';

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('resolveRange', () {
    test('thisMonth resolves to the calendar month', () {
      final controller = ScopeController(householdId: 'h1');
      final range = controller.resolveRange(referenceNow: _d(2026, 8, 15));
      expect(range.start, _d(2026, 8, 1));
      expect(range.end, _d(2026, 8, 31));
    });

    test('lastMonth resolves to the previous calendar month', () {
      final controller = ScopeController(householdId: 'h1')
        ..setPreset(PeriodPreset.lastMonth);
      final range = controller.resolveRange(referenceNow: _d(2026, 8, 15));
      expect(range.start, _d(2026, 7, 1));
      expect(range.end, _d(2026, 7, 31));
    });

    test('last3Months resolves to a 3-month rolling window ending this month', () {
      final controller = ScopeController(householdId: 'h1')
        ..setPreset(PeriodPreset.last3Months);
      final range = controller.resolveRange(referenceNow: _d(2026, 8, 15));
      expect(range.start, _d(2026, 6, 1));
      expect(range.end, _d(2026, 8, 31));
    });

    test('thisYear resolves to Jan 1 - Dec 31 of the current year', () {
      final controller = ScopeController(householdId: 'h1')
        ..setPreset(PeriodPreset.thisYear);
      final range = controller.resolveRange(referenceNow: _d(2026, 8, 15));
      expect(range.start, _d(2026, 1, 1));
      expect(range.end, _d(2026, 12, 31));
    });

    test('last12Months resolves to a rolling 12-month window ending this month', () {
      final controller = ScopeController(householdId: 'h1')
        ..setPreset(PeriodPreset.last12Months);
      final range = controller.resolveRange(referenceNow: _d(2026, 8, 15));
      expect(range.start, _d(2025, 9, 1));
      expect(range.end, _d(2026, 8, 31));
    });

    test('custom range uses the explicit start/end', () {
      final controller = ScopeController(householdId: 'h1')
        ..setCustomRange(_d(2026, 5, 10), _d(2026, 5, 20));
      final range = controller.resolveRange(referenceNow: _d(2026, 8, 15));
      expect(range.start, _d(2026, 5, 10));
      expect(range.end, _d(2026, 5, 20));
    });
  });

  group('stepping', () {
    test('stepBack on thisMonth moves to the previous calendar month', () {
      final controller = ScopeController(householdId: 'h1')..stepBack();
      final range = controller.resolveRange(referenceNow: _d(2026, 8, 15));
      expect(range.start, _d(2026, 7, 1));
      expect(range.end, _d(2026, 7, 31));
    });

    test('stepForward on last3Months jumps a whole quarter', () {
      final controller = ScopeController(householdId: 'h1')
        ..setPreset(PeriodPreset.last3Months)
        ..stepBack();
      final range = controller.resolveRange(referenceNow: _d(2026, 8, 15));
      expect(range.start, _d(2026, 3, 1));
      expect(range.end, _d(2026, 5, 31));
    });

    test('stepping a custom range shifts by its own day-length', () {
      final controller = ScopeController(householdId: 'h1')
        ..setCustomRange(_d(2026, 5, 1), _d(2026, 5, 10))
        ..stepForward();
      final range = controller.resolveRange();
      expect(range.start, _d(2026, 5, 11));
      expect(range.end, _d(2026, 5, 20));
    });

    test('changing preset resets any accumulated step offset', () {
      final controller = ScopeController(householdId: 'h1')
        ..stepBack()
        ..stepBack()
        ..setPreset(PeriodPreset.thisMonth);
      final range = controller.resolveRange(referenceNow: _d(2026, 8, 15));
      expect(range.start, _d(2026, 8, 1));
    });
  });

  group('member selection persistence', () {
    test('toggling a member persists across a fresh controller instance', () async {
      final controller = ScopeController(householdId: 'house-1');
      await controller.load();
      controller.toggleMember('member-a');
      // Flush the async persistence write before constructing a new instance.
      await Future<void>.delayed(Duration.zero);

      final reloaded = ScopeController(householdId: 'house-1');
      await reloaded.load();
      expect(reloaded.selectedMemberIds, {'member-a'});
    });

    test('member selection is scoped per household', () async {
      final controller = ScopeController(householdId: 'house-1');
      await controller.load();
      controller.toggleMember('member-a');
      await Future<void>.delayed(Duration.zero);

      final otherHousehold = ScopeController(householdId: 'house-2');
      await otherHousehold.load();
      expect(otherHousehold.selectedMemberIds, isEmpty);
    });

    test('period selection is never persisted — always resets to thisMonth', () async {
      final controller = ScopeController(householdId: 'house-1');
      await controller.load();
      controller.setPreset(PeriodPreset.thisYear);

      final reloaded = ScopeController(householdId: 'house-1');
      await reloaded.load();
      expect(reloaded.preset, PeriodPreset.thisMonth);
    });
  });
}
