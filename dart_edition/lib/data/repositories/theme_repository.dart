import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../bin/ui_library.dart";

class ThemeSettingsSnapshot {
  final AppThemeMode themeMode;
  final Color themeColor;

  const ThemeSettingsSnapshot({
    required this.themeMode,
    required this.themeColor,
  });
}

abstract class ThemeRepository {
  Future<ThemeSettingsSnapshot> load();

  Future<void> saveThemeMode(AppThemeMode mode);

  Future<void> saveThemeColor(Color color);
}

class SharedPreferencesThemeRepository implements ThemeRepository {
  static const String _themePreferenceKey = "app_theme_mode";
  static const String _colorPreferenceKey = "app_theme_color";

  @override
  Future<ThemeSettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeIndex = prefs.getInt(_themePreferenceKey);
    final savedColorValue = prefs.getInt(_colorPreferenceKey);

    final mode = savedThemeIndex != null &&
            savedThemeIndex >= 0 &&
            savedThemeIndex < AppThemeMode.values.length
        ? AppThemeMode.values[savedThemeIndex]
        : AppThemeMode.system;

    final color = savedColorValue != null
        ? Color(savedColorValue)
        : Colors.lightBlue;

    return ThemeSettingsSnapshot(themeMode: mode, themeColor: color);
  }

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePreferenceKey, mode.index);
  }

  @override
  Future<void> saveThemeColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorPreferenceKey, color.toARGB32());
  }
}
