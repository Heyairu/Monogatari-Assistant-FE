import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/repositories/settings_repository.dart";
import "../../data/repositories/theme_repository.dart";

final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  return SharedPreferencesThemeRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SharedPreferencesSettingsRepository();
});
