import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Quản lý chế độ hiển thị Tối / Sáng toàn ứng dụng (mặc định Dark-first theo `DESIGN.md`).
///
/// Tự động lưu lựa chọn người dùng vào [FlutterSecureStorage] (bỏ qua trong môi trường
/// `flutter test`) và đồng bộ màu biểu tượng thanh trạng thái hệ thống.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController({
    ThemeMode initialMode = ThemeMode.dark,
    FlutterSecureStorage? storage,
  }) : _themeMode = initialMode,
       _storage = storage ?? const FlutterSecureStorage();

  static const String _storageKey = 'meta_gym.theme_mode';

  final FlutterSecureStorage _storage;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isDarkMode => _themeMode != ThemeMode.light;

  /// Đọc chế độ hiển thị đã lưu trước đó (nếu có).
  Future<void> restore() async {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == 'light' && _themeMode != ThemeMode.light) {
        _themeMode = ThemeMode.light;
        _syncSystemUiOverlay();
        notifyListeners();
      } else if (raw == 'dark' && _themeMode != ThemeMode.dark) {
        _themeMode = ThemeMode.dark;
        _syncSystemUiOverlay();
        notifyListeners();
      } else {
        _syncSystemUiOverlay();
      }
    } catch (_) {
      _syncSystemUiOverlay();
    }
  }

  /// Chuyển đổi chế độ hiển thị và lưu bền vững.
  Future<void> setThemeMode(ThemeMode mode) async {
    final normalized = mode == ThemeMode.light
        ? ThemeMode.light
        : ThemeMode.dark;
    if (_themeMode == normalized) return;
    _themeMode = normalized;
    _syncSystemUiOverlay();
    notifyListeners();

    if (MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      await _storage.write(
        key: _storageKey,
        value: normalized == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {}
  }

  /// Bật nhanh chế độ Sáng (`true`) hoặc Tối (`false`).
  Future<void> setLightMode(bool isLight) =>
      setThemeMode(isLight ? ThemeMode.light : ThemeMode.dark);

  /// Đảo qua lại giữa Tối và Sáng.
  Future<void> toggle() => setLightMode(!isLightMode);

  void _syncSystemUiOverlay() {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    SystemChrome.setSystemUIOverlayStyle(
      isLightMode
          ? SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            ),
    );
  }
}
