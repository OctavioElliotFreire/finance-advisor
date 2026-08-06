import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../config/app_config.dart';

@JS()
extension type _PluggyItem._(JSObject _) implements JSObject {
  external JSString get id;
}

@JS()
extension type _PluggySuccessData._(JSObject _) implements JSObject {
  external _PluggyItem get item;
}

@JS()
extension type _PluggyConnectOptions._(JSObject _) implements JSObject {
  external factory _PluggyConnectOptions({
    required JSString connectToken,
    required JSBoolean includeSandbox,
    required JSFunction onSuccess,
    required JSFunction onError,
    required JSFunction onClose,
  });
}

/// Binds to the `PluggyConnect` global injected by the CDN script tag in
/// `web/index.html`. Constructor/options/callback shapes verified against
/// the `pluggy-connect-sdk` README (v2.7.0): `onSuccess` receives
/// `{item: {id, status, executionStatus}}`, matching the mobile
/// `flutter_pluggy_connect` payload documented in `pluggy_connect_screen.dart`.
@JS('PluggyConnect')
extension type _PluggyConnect._(JSObject _) implements JSObject {
  external factory _PluggyConnect(_PluggyConnectOptions options);
  external void init();
  external void destroy();
}

/// Opens Pluggy's official web Connect widget and resolves with the created
/// item id on success, or `null` if the user closes the widget or the
/// connection fails. Mirrors the mobile `PluggyConnectScreen` contract (see
/// that file) so `connections_view.dart` can treat both platforms
/// identically past this point.
Future<String?> openPluggyConnectWeb(String connectToken) {
  if (!globalContext.hasProperty('PluggyConnect'.toJS).toDart) {
    throw StateError(
      'Pluggy Connect script has not loaded yet — check web/index.html and network connectivity.',
    );
  }

  final completer = Completer<String?>();
  late final _PluggyConnect connect;

  void finish(String? itemId) {
    if (!completer.isCompleted) completer.complete(itemId);
    connect.destroy();
  }

  void onSuccess(_PluggySuccessData data) => finish(data.item.id.toDart);
  void onError(JSAny? _) => finish(null);
  void onClose() => finish(null);

  connect = _PluggyConnect(
    _PluggyConnectOptions(
      connectToken: connectToken.toJS,
      includeSandbox: AppConfig.pluggyIncludeSandbox.toJS,
      onSuccess: onSuccess.toJS,
      onError: onError.toJS,
      onClose: onClose.toJS,
    ),
  );
  connect.init();

  return completer.future;
}
