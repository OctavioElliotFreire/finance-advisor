// Non-web platforms use the native flutter_pluggy_connect widget instead
// (see connections_view.dart) — this stub only exists so the conditional
// import in connections_view.dart resolves on mobile/desktop builds.
Future<String?> openPluggyConnectWeb(String connectToken) {
  throw UnsupportedError('Pluggy Connect web widget is only available on web.');
}
