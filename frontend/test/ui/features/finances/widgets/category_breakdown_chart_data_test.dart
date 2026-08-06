import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/models/extended_finance.dart';
import 'package:frontend/ui/features/finances/widgets/category_breakdown_chart_data.dart';

CategoryBreakdownItem _item(String category, double total) {
  return CategoryBreakdownItem(category: category, total: total);
}

void main() {
  group('CategoryBreakdownChartData.fromItems', () {
    test('keeps all categories when at or under the slice cap', () {
      final data = CategoryBreakdownChartData.fromItems([
        _item('Groceries', 500),
        _item('Rent', 1500),
      ]);

      expect(data.isEmpty, isFalse);
      expect(data.slices, hasLength(2));
      expect(data.slices.map((s) => s.label), containsAll(['Groceries', 'Rent']));
      expect(data.slices.any((s) => s.label == 'Other'), isFalse);
    });

    test('folds categories past the cap into an Other slice', () {
      final data = CategoryBreakdownChartData.fromItems([
        _item('Rent', 1500),
        _item('Groceries', 800),
        _item('Transport', 400),
        _item('Dining', 300),
        _item('Utilities', 200),
        _item('Subscriptions', 100),
        _item('Insurance', 90),
      ]);

      expect(data.slices, hasLength(6));
      expect(data.slices.last.label, 'Other');
      expect(data.slices.last.total, closeTo(190, 0.001));
    });

    test('handles a single category without throwing', () {
      final data = CategoryBreakdownChartData.fromItems([_item('Rent', 1500)]);

      expect(data.slices, hasLength(1));
      expect(data.slices.single.label, 'Rent');
    });

    test('handles an empty list without throwing', () {
      final data = CategoryBreakdownChartData.fromItems(const []);

      expect(data.isEmpty, isTrue);
    });
  });
}
