import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Global Dark / Light theme mode controller for Meta Gym.
///
/// Defaults to [ThemeMode.light] and persists the user's selection in secure
/// storage so the preference survives app restarts.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController({
    ThemeMode initialMode = ThemeMode.light,
    FlutterSecureStorage? storage,
    bool? persist,
  }) : _themeMode = initialMode,
       _storage = storage ?? const FlutterSecureStorage(),
       _persist = persist ?? !MetaGymTheme.isFlutterTestEnvironment;

  static const String storageKey = 'meta_gym_theme_mode';

  final FlutterSecureStorage _storage;
  final bool _persist;

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;
  bool get isLight => _themeMode == ThemeMode.light;

  /// Restores the saved theme preference if available.
  Future<void> restore() async {
    if (!_persist) return;
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == 'light' && _themeMode != ThemeMode.light) {
        _themeMode = ThemeMode.light;
        notifyListeners();
      } else if (raw == 'dark' && _themeMode != ThemeMode.dark) {
        _themeMode = ThemeMode.dark;
        notifyListeners();
      }
    } catch (_) {
      // Keep default dark-first theme when storage is unavailable.
    }
  }

  /// Updates the active [ThemeMode] and persists it asynchronously.
  Future<void> setThemeMode(ThemeMode mode) async {
    final normalized = mode == ThemeMode.light
        ? ThemeMode.light
        : ThemeMode.dark;
    if (_themeMode == normalized) return;
    _themeMode = normalized;
    notifyListeners();
    if (!_persist) return;
    try {
      await _storage.write(
        key: storageKey,
        value: normalized == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {
      // Non-fatal: in-memory state is already updated.
    }
  }

  Future<void> toggle() =>
      setThemeMode(isLight ? ThemeMode.dark : ThemeMode.light);
}
