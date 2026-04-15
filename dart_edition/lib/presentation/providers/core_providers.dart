import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/repositories/file_repository.dart";
import "../../data/repositories/glossary_repository.dart";
import "../../data/repositories/settings_repository.dart";
import "../../data/repositories/theme_repository.dart";
import "../../domain/usecases/app_bootstrap_usecase.dart";
import "../../domain/usecases/project_file_usecase.dart";

final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  return SharedPreferencesThemeRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SharedPreferencesSettingsRepository();
});

final fileRepositoryProvider = Provider<FileRepository>((ref) {
  return DefaultFileRepository();
});

final glossaryRepositoryProvider = Provider<GlossaryRepository>((ref) {
  return LocalFileGlossaryRepository();
});

final appBootstrapUseCaseProvider = Provider<AppBootstrapUseCase>((ref) {
  return AppBootstrapUseCase(
    themeRepository: ref.watch(themeRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

final projectFileUseCaseProvider = Provider<ProjectFileUseCase>((ref) {
  return ProjectFileUseCase(fileRepository: ref.watch(fileRepositoryProvider));
});
