import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Reads app settings from Firebase Remote Config, so they can be changed in
/// the Firebase console without releasing a new version of the app.
///
/// Security: Remote Config values can be read by anyone who has the app,
/// so they must never contain secrets. Only people with access to the
/// Firebase console can change them.
class ConfigService {
  ConfigService({FirebaseRemoteConfig? remoteConfig})
    : _rcOverride = remoteConfig;

  static const String keyAiModel = 'ai_model';
  static const String keySystemPrompt = 'system_prompt';

  final FirebaseRemoteConfig? _rcOverride;
  FirebaseRemoteConfig get _rc => _rcOverride ?? FirebaseRemoteConfig.instance;

  bool _loaded = false;

  /// Fetches the latest values. Never throws: if it fails (for example, no
  /// internet), the app simply uses its built-in defaults.
  Future<void> load() async {
    try {
      await _rc.setConfigSettings(
        RemoteConfigSettings(
          // Short: the app waits for this before it opens.
          fetchTimeout: const Duration(seconds: 3),
          // Debug: pick up console changes quickly. Release: at most hourly,
          // which also keeps us well inside Remote Config's fetch limits.
          minimumFetchInterval: kDebugMode
              ? const Duration(minutes: 1)
              : const Duration(hours: 1),
        ),
      );
      await _rc.fetchAndActivate().timeout(const Duration(seconds: 4));
      _loaded = true;
      // Debug only: shows exactly what arrived (values are not secret), to
      // check console changes. An invalid model name falls back to the
      // built-in default.
      if (kDebugMode) {
        debugPrint(
          'Remote Config loaded: $keyAiModel="${_rc.getString(keyAiModel)}" '
          '(last fetch: ${_rc.lastFetchStatus.name})',
        );
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Remote Config not loaded: $error');
    }
  }

  /// The model name set in the console, or '' if none.
  String get aiModel => _read(keyAiModel);

  /// A replacement system prompt set in the console, or '' if none.
  String get systemPrompt => _read(keySystemPrompt);

  String _read(String key) {
    if (!_loaded) return '';
    try {
      return _rc.getString(key).trim();
    } catch (_) {
      return '';
    }
  }
}
