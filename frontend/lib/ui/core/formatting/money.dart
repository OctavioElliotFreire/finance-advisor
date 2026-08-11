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

/// The third date format `design.md`'s Localization section names —
/// `6 de ago` — for transaction-row subtitles (no year, since the period
/// pill above already scopes the range). Strips the trailing period intl's
/// pt-BR abbreviated month names carry (`ago.`) since the spec's own
/// example has none.
String formatDayMonth(DateTime date) {
  final month = DateFormat('MMM', 'pt_BR').format(date).replaceAll('.', '');
  return '${date.day} de $month';
}

/// Masks all but the last 4 characters of an account number for Contas ·
/// Extrato's sticky subheader — `design.md`'s §6.2 mockup shows a masked
/// number without specifying an exact format, so this follows the common
/// bank-app convention (`•••• 1234`). Non-digit separators (`-`, spaces)
/// are stripped first so a raw Pluggy-style number like `0001-1234567`
/// masks to its last 4 characters, not the separator's position.
String formatMaskedAccountNumber(String? number) {
  if (number == null || number.isEmpty) return '••••';
  final cleaned = number.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  if (cleaned.isEmpty) return '••••';
  final visible = cleaned.length <= 4 ? cleaned : cleaned.substring(cleaned.length - 4);
  return '•••• $visible';
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
