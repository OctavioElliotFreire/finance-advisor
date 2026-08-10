import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Flutter's test runner picks up a `flutter_test_config.dart` at the test
/// root automatically and runs it before every test file in this directory
/// tree — this is where pt-BR locale data gets initialized for the whole
/// suite, mirroring what `main.dart` does at real app startup, so any code
/// under test that calls `DateFormat`/`NumberFormat` with `locale: 'pt_BR'`
/// doesn't hit `LocaleDataException: Locale data has not been initialized`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  await testMain();
}
