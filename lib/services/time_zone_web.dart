import 'dart:js_interop';

// The browser's built-in Intl.DateTimeFormat, which knows the time zone.
@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external JSString? get timeZone;
}

/// The browser's time zone name, like "Asia/Bangkok", or null if unknown.
String? deviceTimeZoneName() {
  try {
    final name = _DateTimeFormat().resolvedOptions().timeZone?.toDart;
    // Only plain zone names ("Area/City"), so nothing odd reaches the prompt.
    final ok =
        name != null &&
        name.length <= 64 &&
        RegExp(
          r'^[A-Za-z][A-Za-z0-9_+\-]*(/[A-Za-z0-9_+\-]+)*$',
        ).hasMatch(name);
    return ok ? name : null;
  } catch (_) {
    return null;
  }
}
