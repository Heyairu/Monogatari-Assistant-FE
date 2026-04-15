import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../bin/file.dart";
import "../../modules/baseinfoview.dart" as base_info_module;
import "../../modules/chapterselectionview.dart" as chapter_module;
import "../../modules/characterview.dart";
import "../../modules/outlineview.dart" as outline_module;
import "../../modules/worldsettingsview.dart";
import "core_providers.dart";

enum ProjectIoOperation {
  idle,
  newProject,
  openProject,
  openRecentProject,
  saveProject,
  saveProjectAs,
  exportText,
  exportSelective,
}

class ProjectIoStatus {
  final ProjectIoOperation operation;
  final String? message;

  const ProjectIoStatus({required this.operation, this.message});

  const ProjectIoStatus.idle() : this(operation: ProjectIoOperation.idle);
}

class ProjectLoadResult {
  final ProjectFile projectFile;
  final ProjectData data;

  const ProjectLoadResult({required this.projectFile, required this.data});
}

class ProjectIoController extends AsyncNotifier<ProjectIoStatus> {
  @override
  Future<ProjectIoStatus> build() async {
    return const ProjectIoStatus.idle();
  }

  Future<ProjectLoadResult> createNewProject() async {
    state = const AsyncLoading();
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final projectFile = await useCase.createNewProject();
      final data = ProjectData.empty();
      state = const AsyncData(
        ProjectIoStatus(
          operation: ProjectIoOperation.newProject,
          message: "新專案建立成功！",
        ),
      );
      return ProjectLoadResult(projectFile: projectFile, data: data);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<ProjectFile?> pickProjectFile() async {
    state = const AsyncLoading();
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final projectFile = await useCase.openProject();
      state = const AsyncData(
        ProjectIoStatus(operation: ProjectIoOperation.openProject),
      );
      return projectFile;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<ProjectFile> openProjectFromPath(
    String filePath, {
    String? accessToken,
  }) async {
    state = const AsyncLoading();
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final projectFile = await useCase.openProjectFromPath(
        filePath,
        accessToken: accessToken,
      );
      state = const AsyncData(
        ProjectIoStatus(operation: ProjectIoOperation.openRecentProject),
      );
      return projectFile;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<ProjectData> loadProjectData(ProjectFile projectFile) async {
    state = const AsyncLoading();
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final data = await useCase.loadProjectFromXml(projectFile);
      state = const AsyncData(ProjectIoStatus(operation: ProjectIoOperation.openProject));
      return data;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<ProjectFile> saveProject({
    required ProjectFile? currentProject,
    required ProjectData currentData,
    required bool forceSaveAs,
  }) async {
    state = const AsyncLoading();
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final projectToSave = currentProject ?? await useCase.createNewProject();
      final xmlContent = await useCase.generateProjectXml(currentData);
      projectToSave.content = xmlContent;

      final shouldSaveAs = forceSaveAs || currentProject == null;
      final savedProject = shouldSaveAs
          ? await useCase.saveProjectAs(projectToSave)
          : await useCase.saveProject(projectToSave);

      state = AsyncData(
        ProjectIoStatus(
          operation: shouldSaveAs
              ? ProjectIoOperation.saveProjectAs
              : ProjectIoOperation.saveProject,
          message: shouldSaveAs
              ? "專案另存成功：${savedProject.nameWithoutExtension}"
              : "專案儲存成功！",
        ),
      );
      return savedProject;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> exportAs({
    required String extension,
    required ProjectData currentData,
    required String defaultFileName,
  }) async {
    state = const AsyncLoading();
    try {
      final buffer = StringBuffer();
      for (final segment in currentData.segmentsData) {
        buffer.writeln("# ${segment.segmentName}");
        buffer.writeln();
        for (final chapter in segment.chapters) {
          buffer.writeln("## ${chapter.chapterName}");
          buffer.writeln();
          buffer.writeln(chapter.chapterContent);
          buffer.writeln();
        }
      }

      await ref.read(projectFileUseCaseProvider).exportText(
        content: buffer.toString(),
        fileName: defaultFileName,
        extension: extension == "txt" ? ".txt" : ".md",
      );

      state = AsyncData(
        ProjectIoStatus(
          operation: ProjectIoOperation.exportText,
          message: "匯出 $extension 檔案成功！",
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> exportSelective({
    required ProjectData currentData,
    required String defaultFileName,
    required Set<String> selectedModules,
    required String format,
  }) async {
    state = const AsyncLoading();
    try {
      final buffer = StringBuffer();

      if (format == "xml") {
        buffer.writeln("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        buffer.writeln("<Project>");
        buffer.writeln("<ver>${FileService.projectVersion}</ver>");

        if (selectedModules.contains("BaseInfo")) {
          final xml = base_info_module.BaseInfoCodec.saveXML(
            data: currentData.baseInfoData,
            totalWords: currentData.totalWords,
            contentText: currentData.contentText,
          );
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("Chapters")) {
          final xml = chapter_module.ChapterSelectionCodec.saveXML(
            currentData.segmentsData,
          );
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("Outline")) {
          final xml = outline_module.OutlineCodec.saveXML(
            currentData.outlineData,
          );
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("WorldSettings")) {
          final xml = WorldSettingsCodec.saveXML(currentData.worldSettingsData);
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("Characters")) {
          final xml = CharacterCodec.saveXML(currentData.characterData);
          if (xml != null) buffer.writeln(xml);
        }

        buffer.writeln("</Project>");
      } else {
        if (selectedModules.contains("BaseInfo")) {
          final xml = base_info_module.BaseInfoCodec.saveXML(
            data: currentData.baseInfoData,
            totalWords: currentData.totalWords,
            contentText: currentData.contentText,
          );
          buffer.writeln("## BaseInfo");
          buffer.writeln();
          if (xml != null) {
            buffer.writeln("```xml");
            buffer.writeln(xml);
            buffer.writeln("```");
          }
          buffer.writeln();
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("Chapters")) {
          final xml = chapter_module.ChapterSelectionCodec.saveXML(
            currentData.segmentsData,
          );
          buffer.writeln("## Chapters");
          buffer.writeln();
          if (xml != null) {
            buffer.writeln("```xml");
            buffer.writeln(xml);
            buffer.writeln("```");
          }
          buffer.writeln();
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("Outline")) {
          final xml = outline_module.OutlineCodec.saveXML(
            currentData.outlineData,
          );
          buffer.writeln("## Outline");
          buffer.writeln();
          if (xml != null) {
            buffer.writeln("```xml");
            buffer.writeln(xml);
            buffer.writeln("```");
          }
          buffer.writeln();
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("WorldSettings")) {
          final xml = WorldSettingsCodec.saveXML(currentData.worldSettingsData);
          buffer.writeln("## WorldSettings");
          buffer.writeln();
          if (xml != null) {
            buffer.writeln("```xml");
            buffer.writeln(xml);
            buffer.writeln("```");
          }
          buffer.writeln();
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("Characters")) {
          final xml = CharacterCodec.saveXML(currentData.characterData);
          buffer.writeln("## Characters");
          buffer.writeln();
          if (xml != null) {
            buffer.writeln("```xml");
            buffer.writeln(xml);
            buffer.writeln("```");
          }
          buffer.writeln();
          buffer.writeln("---");
          buffer.writeln();
        }
      }

      await ref.read(projectFileUseCaseProvider).exportText(
            content: buffer.toString(),
            fileName: defaultFileName,
            extension: format == "xml" ? ".xml" : ".md",
          );

      state = const AsyncData(
        ProjectIoStatus(
          operation: ProjectIoOperation.exportSelective,
          message: "匯出成功！",
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final projectIoControllerProvider =
    AsyncNotifierProvider<ProjectIoController, ProjectIoStatus>(
      ProjectIoController.new,
    );
