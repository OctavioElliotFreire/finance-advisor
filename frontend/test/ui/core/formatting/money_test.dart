import 'package:frontend/ui/core/formatting/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

const _nbsp = ' ';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
  });

  group('formatMoney', () {
    // intl's pt_BR currency pattern inserts a non-breaking space (U+00A0,
    // not a regular space) between the symbol and the amount — asserting
    // the literal NBSP here (via the `_nbsp` const) rather than a plain
    // space so this test would actually fail if that ever silently changed.
    test('formats BRL with pt-BR grouping/decimal separators', () {
      expect(formatMoney(8450.0, 'BRL'), 'R\$${_nbsp}8.450,00');
    });

    test('formats negative amounts with a leading minus sign', () {
      expect(formatMoney(-142.30, 'BRL'), '-R\$${_nbsp}142,30');
    });

    test('formats large amounts with multiple thousand separators', () {
      expect(formatMoney(1234567.89, 'BRL'), 'R\$${_nbsp}1.234.567,89');
    });
  });

  group('formatShortDate', () {
    test('formats as dd/MM/yyyy', () {
      expect(formatShortDate(DateTime(2026, 8, 28)), '28/08/2026');
    });
  });

  group('formatMonth', () {
    test('formats a yyyy-MM string as a compact pt-BR month/year label', () {
      expect(formatMonth('2026-08'), 'ago./26');
    });
  });
}
