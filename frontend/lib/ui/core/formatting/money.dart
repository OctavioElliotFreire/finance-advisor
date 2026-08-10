import 'package:intl/intl.dart';

/// pt-BR money formatting per `design.md`'s Localization section:
/// `R$ 8.450,00` (space after `R\$`, `.` thousands, `,` decimals), negatives
/// with a leading minus sign, never parentheses. This app is Brazilian-only
/// (all Pluggy accounts are BRL) so the symbol is always `R\$`; `currencyCode`
/// is kept for signature stability and falls back to the raw code for the
/// unexpected non-BRL case rather than guessing a symbol for it.
String formatMoney(double amount, String currencyCode) {
  final symbol = currencyCode == 'BRL' ? 'R\$' : currencyCode;
  return NumberFormat.currency(
    locale: 'pt_BR',
    symbol: symbol,
    decimalDigits: 2,
  ).format(amount);
}

/// Compact month/year label for chart axis ticks — `DateFormat.yMMM`'s
/// pt-BR pattern ("abr. de 2026") overlaps neighboring labels at narrow
/// (mobile) widths on a 5+ tick axis; `MMM/yy` ("abr./26") carries the same
/// information in roughly half the width.
String formatMonth(String yearMonth) {
  final parts = yearMonth.split('-');
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
  return DateFormat('MMM/yy', 'pt_BR').format(date);
}

String formatShortDate(DateTime date) {
  return DateFormat.yMd('pt_BR').format(date);
}

/// Relative time for lists/footers per `design.md`'s Localization section:
/// `há 2h`, `ontem`, `terça`. `now` is injectable for tests; defaults to
/// `DateTime.now()`.
String formatRelativeTime(DateTime dateTime, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(dateTime);

  if (diff.inMinutes < 1) return 'agora';
  if (diff.inHours < 1) return 'há ${diff.inMinutes}min';
  if (diff.inHours < 24 && dateTime.day == reference.day) {
    return 'há ${diff.inHours}h';
  }

  final today = DateTime(reference.year, reference.month, reference.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
  if (dateDay == yesterday) return 'ontem';

  if (diff.inDays < 7) {
    final weekday = DateFormat('EEEE', 'pt_BR').format(dateTime);
    return weekday.replaceAll('-feira', '');
  }

  return formatShortDate(dateTime);
}
