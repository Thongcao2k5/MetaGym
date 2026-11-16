import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Persists Member-chosen muscle anatomy icon keys per scheduled self-training date.
class SelfTrainingIconStore {
  SelfTrainingIconStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _storageKey = 'member_self_training_icons_v1';
  static final Map<String, String> _memory = {};

  final FlutterSecureStorage _storage;

  @visibleForTesting
  static void clearMemoryCache() => _memory.clear();

  Future<Map<String, String>> loadAll() async {
    if (MetaGymTheme.isFlutterTestEnvironment) {
      return Map<String, String>.unmodifiable(_memory);
    }
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key?.toString();
            final value = entry.value?.toString();
            if (key != null && value != null && value.isNotEmpty) {
              _memory[key] = value;
            }
          }
        }
      }
    } catch (_) {
      // Fallback to in-memory cache when secure storage is unavailable (e.g. tests).
    }
    return Map<String, String>.unmodifiable(_memory);
  }

  String? getCached(String dateKey) => _memory[dateKey];

  Future<void> setIcon(String dateKey, String? iconKey) async {
    if (iconKey == null || iconKey.trim().isEmpty) {
      await removeIcon(dateKey);
      return;
    }
    _memory[dateKey] = iconKey.trim();
    await _persist();
  }

  Future<void> removeIcon(String dateKey) async {
    _memory.remove(dateKey);
    await _persist();
  }

  Future<void> _persist() async {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(_memory));
    } catch (_) {
      // Safe no-op in widget test environments without platform storage.
    }
  }
}
