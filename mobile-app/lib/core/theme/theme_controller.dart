import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the user's appearance independently of the signed-in account.
class ThemeController extends ChangeNotifier {
  ThemeController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'meta_gym_theme_mode';
  static const _reduceBlurKey = 'meta_gym_reduce_blur';
  final FlutterSecureStorage _storage;
  ThemeMode _mode = ThemeMode.dark;
  bool _changed = false;
  bool _reduceBlurChanged = false;
  bool _reduceBlur = false;
  bool _disposed = false;
  Future<void> _pendingWrite = Future.value();

  ThemeMode get mode => _mode;
  bool get reduceBlur => _reduceBlur;

  Future<void> restore() async {
    try {
      final saved = await _storage.read(key: _key);
      final savedReduceBlur = await _storage.read(key: _reduceBlurKey);
      if (_disposed) return;
      if (!_changed && saved != null) {
        _mode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
      }
      if (!_reduceBlurChanged && savedReduceBlur != null) {
        _reduceBlur = savedReduceBlur == 'true';
      }
      notifyListeners();
    } catch (_) {
      // Storage may be unavailable on a particular platform; keep the default.
    }
  }

  void setReduceBlur(bool value) {
    _reduceBlurChanged = true;
    if (_reduceBlur != value) {
      _reduceBlur = value;
      notifyListeners();
    }
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _storage.write(key: _reduceBlurKey, value: value.toString());
      } catch (_) {
        // Keep the current in-memory setting if persistence is unavailable.
      }
    });
  }

  void setMode(ThemeMode mode) {
    if (mode != ThemeMode.light && mode != ThemeMode.dark) return;
    _changed = true;
    if (_mode != mode) {
      _mode = mode;
      notifyListeners();
    }
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await _storage.write(key: _key, value: mode.name);
      } catch (_) {
        // The in-memory selection remains active if persistence fails.
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Shared surface preference, also available to routes and modal overlays.
class MetaGymSurfacePreferences extends InheritedWidget {
  const MetaGymSurfacePreferences({
    required this.reduceBlur,
    required super.child,
    super.key,
  });

  final bool reduceBlur;

  static bool reduceBlurOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MetaGymSurfacePreferences>()
          ?.reduceBlur ??
      false;

  @override
  bool updateShouldNotify(MetaGymSurfacePreferences oldWidget) =>
      reduceBlur != oldWidget.reduceBlur;
}
