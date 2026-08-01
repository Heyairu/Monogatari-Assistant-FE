import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/repositories/file_repository.dart";
import "../../data/repositories/glossary_repository.dart";
import "../../application/usecases/app_bootstrap_usecase.dart";
import "../../domain/usecases/project_file_usecase.dart";
import "repository_providers.dart";

export "repository_providers.dart";

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
