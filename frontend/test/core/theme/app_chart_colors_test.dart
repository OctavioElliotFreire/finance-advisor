import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_chart_colors.dart';

void main() {
  test('categoricalColorFor is deterministic per label', () {
    final first = AppChartColors.categoricalPalette[
        'Groceries'.hashCode.abs() % AppChartColors.categoricalPalette.length];
    final second = AppChartColors.categoricalPalette[
        'Groceries'.hashCode.abs() % AppChartColors.categoricalPalette.length];

    expect(first, second);
  });

  test('different labels can map to different palette slots', () {
    final index1 = 'Groceries'.hashCode.abs() % AppChartColors.categoricalPalette.length;
    final index2 = 'Transport'.hashCode.abs() % AppChartColors.categoricalPalette.length;

    expect(AppChartColors.categoricalPalette[index1], isNotNull);
    expect(AppChartColors.categoricalPalette[index2], isNotNull);
  });
}
