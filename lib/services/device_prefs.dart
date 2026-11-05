import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small settings kept on this device only (never in Firestore): whether
/// the welcome tour and the splash intro have been seen.
///
/// Uses SharedPreferencesAsync (browser storage on web). Every read and
/// write is allowed to fail (for example private browsing): the app then
/// behaves as on a first visit, which is always safe.
class DevicePrefs {
  DevicePrefs({SharedPreferencesAsync? prefs}) : _prefsOverride = prefs;

  static const keyOnboardingSeen = 'onboardingSeen';
  static const keySplashIntroSeen = 'splashIntroSeen';

  final SharedPreferencesAsync? _prefsOverride;
  late final SharedPreferencesAsync _prefs =
      _prefsOverride ?? SharedPreferencesAsync();

  /// True once the user tapped Skip, Create an account or I already have an
  /// account in the welcome tour.
  Future<bool> onboardingSeen() => _read(keyOnboardingSeen);
  Future<void> setOnboardingSeen() => _write(keyOnboardingSeen);

  /// True once the splash intro has played to the end on this device.
  Future<bool> splashIntroSeen() => _read(keySplashIntroSeen);
  Future<void> setSplashIntroSeen() => _write(keySplashIntroSeen);

  Future<bool> _read(String key) async {
    try {
      return await _prefs.getBool(key) ?? false;
    } catch (error) {
      if (kDebugMode) debugPrint('Device setting "$key" not read: $error');
      return false;
    }
  }

  Future<void> _write(String key) async {
    try {
      await _prefs.setBool(key, true);
    } catch (error) {
      if (kDebugMode) debugPrint('Device setting "$key" not saved: $error');
    }
  }
}
