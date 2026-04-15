import "../../data/repositories/settings_repository.dart";
import "../../data/repositories/theme_repository.dart";

class AppBootstrapSnapshot {
  final ThemeSettingsSnapshot theme;
  final SettingsSnapshot settings;

  const AppBootstrapSnapshot({
    required this.theme,
    required this.settings,
  });
}

class AppBootstrapUseCase {
  final ThemeRepository themeRepository;
  final SettingsRepository settingsRepository;

  const AppBootstrapUseCase({
    required this.themeRepository,
    required this.settingsRepository,
  });

  Future<AppBootstrapSnapshot> call() async {
    final results = await Future.wait([
      themeRepository.load(),
      settingsRepository.load(),
    ]);

    return AppBootstrapSnapshot(
      theme: results[0] as ThemeSettingsSnapshot,
      settings: results[1] as SettingsSnapshot,
    );
  }
}
