import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _themeKey = 'app_theme_mode';
  final _storage = const FlutterSecureStorage();

  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    try {
      final value = await _storage.read(key: _themeKey);
      if (value != null) {
        state = ThemeMode.values.firstWhere(
          (e) => e.name == value,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      // Ignore reading exceptions
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      await _storage.write(key: _themeKey, value: mode.name);
    } catch (e) {
      // Ignore writing exceptions
    }
  }
}
