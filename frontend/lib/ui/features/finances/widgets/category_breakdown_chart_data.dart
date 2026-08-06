import '../../../../data/models/extended_finance.dart';

const _maxSlices = 6;

class CategoryBreakdownSlice {
  const CategoryBreakdownSlice({required this.label, required this.total});

  final String label;
  final double total;
}

class CategoryBreakdownChartData {
  const CategoryBreakdownChartData({required this.slices});

  factory CategoryBreakdownChartData.fromItems(
    List<CategoryBreakdownItem> items,
  ) {
    final sorted = [...items]..sort((a, b) => b.total.compareTo(a.total));

    if (sorted.length <= _maxSlices) {
      return CategoryBreakdownChartData(
        slices: [
          for (final item in sorted)
            CategoryBreakdownSlice(
              label: item.category ?? 'Uncategorized',
              total: item.total,
            ),
        ],
      );
    }

    final top = sorted.take(_maxSlices - 1);
    final rest = sorted.skip(_maxSlices - 1);
    final otherTotal = rest.fold<double>(0, (sum, item) => sum + item.total);

    return CategoryBreakdownChartData(
      slices: [
        for (final item in top)
          CategoryBreakdownSlice(
            label: item.category ?? 'Uncategorized',
            total: item.total,
          ),
        CategoryBreakdownSlice(label: 'Other', total: otherTotal),
      ],
    );
  }

  final List<CategoryBreakdownSlice> slices;

  bool get isEmpty => slices.isEmpty;
}
