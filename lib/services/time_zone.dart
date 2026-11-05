/// The device's time zone name, like "Asia/Bangkok".
///
/// On web it comes from the browser. Elsewhere (Android) Dart only knows an
/// abbreviation, so it returns null and callers fall back to the UTC offset.
library;

export 'time_zone_stub.dart' if (dart.library.js_interop) 'time_zone_web.dart';
