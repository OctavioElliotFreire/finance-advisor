import 'package:intl/intl.dart';

String formatMoney(double amount, String currencyCode) {
  return NumberFormat.simpleCurrency(name: currencyCode).format(amount);
}

String formatMonth(String yearMonth) {
  final parts = yearMonth.split('-');
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
  return DateFormat.yMMM().format(date);
}

String formatShortDate(DateTime date) {
  return DateFormat.yMd().format(date);
}
