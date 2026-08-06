import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../bin/file.dart";
import "../../modules/baseinfoview.dart" as base_info_module;
import "../../modules/chapterselectionview.dart" as chapter_module;
import "../../modules/characterview.dart";
import "../../modules/outlineview.dart" as outline_module;
import "../../modules/worldsettingsview.dart";
import "../../models/codecs/timeline_codec.dart";
import "core_providers.dart";
import "project_snapshot_utils.dart";

enum ProjectIoOperation {
  idle,
  newProject,
  openProject,
  openRecentProject,
  saveProject,
  saveProjectAs,
  saveProjectAutoSave,
  saveProjectAutoBackup,
  exportText,
  exportSelective,
}

class ProjectIoStatus {
  final ProjectIoOperation operation;
  final String? message;
  final bool isOpeningProject;
  final bool isSaving;
  final bool isExporting;
  final bool isParsing;

  const ProjectIoStatus({
    required this.operation,
    this.message,
    this.isOpeningProject = false,
    this.isSaving = false,
    this.isExporting = false,
    this.isParsing = false,
  });

  const ProjectIoStatus.idle() : this(operation: ProjectIoOperation.idle);

  bool get isBusy => isOpeningProject || isSaving || isExporting || isParsing;

  bool get blocksEditor => isOpeningProject || isParsing;
}

class ProjectLoadResult {
  final ProjectFile projectFile;
  final ProjectData data;
  final String? projectVersion;
  final List<ProjectMigrationWarning> migrationWarnings;
  final bool wasMigrated;

  const ProjectLoadResult({
    required this.projectFile,
    required this.data,
    this.projectVersion,
    this.migrationWarnings = const <ProjectMigrationWarning>[],
    this.wasMigrated = false,
  });
}

class AutoBackupResult {
  final String? path;
  final bool wasWritten;

  const AutoBackupResult._({required this.path, required this.wasWritten});

  const AutoBackupResult.written({required String path})
    : this._(path: path, wasWritten: true);
}

class ProjectIoPayload {
  final ProjectData snapshot;
  final String xmlContent;

  const ProjectIoPayload({required this.snapshot, required this.xmlContent});
}

class ProjectIoController extends AsyncNotifier<ProjectIoStatus> {
  @override
  ProjectIoStatus build() => const ProjectIoStatus.idle();

  Future<ProjectIoPayload> prepareProjectPayload(
    ProjectData currentData,
  ) async {
    final useCase = ref.read(projectFileUseCaseProvider);
    final baseInfoSnapshot = base_info_module.BaseInfoCodec.createSaveSnapshot(
      data: currentData.baseInfoData,
      contentText: currentData.contentText,
    );
    final snapshotData = snapshotProjectData(
      currentData,
      baseInfoOverride: baseInfoSnapshot,
    );
    final xmlContent = await useCase.generateProjectXml(snapshotData);
    return ProjectIoPayload(snapshot: snapshotData, xmlContent: xmlContent);
  }

  Future<ProjectLoadResult> createNewProject() async {
    state = const AsyncData(
      ProjectIoStatus(
        operation: ProjectIoOperation.newProject,
        isOpeningProject: true,
      ),
    );
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final projectFile = await useCase.createNewProject();
      final data = snapshotProjectData(ProjectData.empty());
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
    state = const AsyncData(
      ProjectIoStatus(
        operation: ProjectIoOperation.openProject,
        isOpeningProject: true,
      ),
    );
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
    state = const AsyncData(
      ProjectIoStatus(
        operation: ProjectIoOperation.openRecentProject,
        isOpeningProject: true,
      ),
    );
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
    final result = await loadProject(projectFile);
    return result.data;
  }

  Future<ProjectLoadResult> loadProject(ProjectFile projectFile) async {
    state = const AsyncData(
      ProjectIoStatus(
        operation: ProjectIoOperation.openProject,
        isParsing: true,
      ),
    );
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final parseResult = await useCase.loadProjectParseResultFromXml(
        projectFile,
      );
      final snapshot = snapshotProjectData(parseResult.data);
      state = const AsyncData(
        ProjectIoStatus(
          operation: ProjectIoOperation.openProject,
          message: "專案解析完成",
        ),
      );
      return ProjectLoadResult(
        projectFile: projectFile,
        data: snapshot,
        projectVersion: parseResult.projectVersion,
        migrationWarnings: parseResult.migrationWarnings,
        wasMigrated: parseResult.wasMigrated,
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<ProjectFile> saveProject({
    required ProjectFile? currentProject,
    required ProjectData currentData,
    required bool forceSaveAs,
    ProjectIoPayload? preparedPayload,
  }) async {
    final shouldSaveAs = forceSaveAs || currentProject == null;
    final operation = shouldSaveAs
        ? ProjectIoOperation.saveProjectAs
        : ProjectIoOperation.saveProject;
    state = AsyncData(ProjectIoStatus(operation: operation, isSaving: true));
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final projectToSave = currentProject ?? await useCase.createNewProject();

      final payload =
          preparedPayload ?? await prepareProjectPayload(currentData);
      projectToSave.content = payload.xmlContent;

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

  Future<ProjectFile> saveProjectAutoSave({
    required ProjectFile currentProject,
    required ProjectData currentData,
    ProjectIoPayload? preparedPayload,
  }) async {
    state = const AsyncData(
      ProjectIoStatus(
        operation: ProjectIoOperation.saveProjectAutoSave,
        isSaving: true,
      ),
    );
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final payload =
          preparedPayload ?? await prepareProjectPayload(currentData);
      currentProject.content = payload.xmlContent;
      final savedProject = await useCase.saveProjectToKnownLocation(
        currentProject,
      );

      state = const AsyncData(
        ProjectIoStatus(
          operation: ProjectIoOperation.saveProjectAutoSave,
          message: "自動儲存完成",
        ),
      );
      return savedProject;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<AutoBackupResult> saveProjectAutoBackup({
    required ProjectFile? currentProject,
    required ProjectData currentData,
    required int maxTotalBytes,
    ProjectIoPayload? preparedPayload,
  }) async {
    state = const AsyncData(
      ProjectIoStatus(
        operation: ProjectIoOperation.saveProjectAutoBackup,
        isSaving: true,
      ),
    );
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final payload =
          preparedPayload ?? await prepareProjectPayload(currentData);
      final xmlContent = payload.xmlContent;

      final projectName =
          currentProject?.nameWithoutExtension.trim().isNotEmpty == true
          ? currentProject!.nameWithoutExtension
          : FileService.defaultFileName;
      final backupPath = await useCase.saveProjectAutoBackup(
        projectName: projectName,
        content: xmlContent,
        maxTotalBytes: maxTotalBytes,
      );

      state = const AsyncData(
        ProjectIoStatus(
          operation: ProjectIoOperation.saveProjectAutoBackup,
          message: "AutoBackup 已建立",
        ),
      );
      return AutoBackupResult.written(path: backupPath);
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
    state = const AsyncData(
      ProjectIoStatus(
        operation: ProjectIoOperation.exportText,
        isExporting: true,
      ),
    );
    try {
      final snapshotData = snapshotProjectData(currentData);
      final buffer = StringBuffer();
      String heading(int depth) => List.filled(depth, "#").join();
      void writeFolder(chapter_module.SegmentData folder, int depth) {
        buffer.writeln("${heading(depth)} ${folder.segmentName}");
        buffer.writeln();
        for (final chapter in folder.chapters) {
          buffer.writeln("${heading(depth + 1)} ${chapter.chapterName}");
          buffer.writeln();
          buffer.writeln(chapter.chapterContent);
          buffer.writeln();
        }
        for (final child in folder.childSegments) {
          writeFolder(child, depth + 1);
        }
      }

      for (final folder in snapshotData.segmentsData) {
        writeFolder(folder, 1);
      }

      await ref
          .read(projectFileUseCaseProvider)
          .exportText(
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
    state = const AsyncData(
      ProjectIoStatus(
        operation: ProjectIoOperation.exportSelective,
        isExporting: true,
      ),
    );
    try {
      final snapshotData = snapshotProjectData(currentData);
      final buffer = StringBuffer();

      if (format == "xml") {
        buffer.writeln("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        buffer.writeln("<Project>");
        buffer.writeln("<ver>${FileService.projectVersion}</ver>");

        if (selectedModules.contains("BaseInfo")) {
          final baseInfoSnapshot =
              base_info_module.BaseInfoCodec.createSaveSnapshot(
                data: snapshotData.baseInfoData,
                contentText: snapshotData.contentText,
                updateLatestSave: false,
              );
          final xml = base_info_module.BaseInfoCodec.saveXML(
            data: snapshotData.baseInfoData,
            totalWords: snapshotData.totalWords,
            contentText: snapshotData.contentText,
            updateLatestSave: false,
            snapshot: baseInfoSnapshot,
          );
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("Chapters")) {
          final xml = chapter_module.ChapterSelectionCodec.saveXML(
            snapshotData.segmentsData,
          );
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("Outline")) {
          final xml = outline_module.OutlineCodec.saveXML(
            snapshotData.outlineData,
          );
          if (xml != null) buffer.writeln(xml);
          final timelineXml = TimelineCodec.saveXML(
            snapshotData.timelineDocument,
            snapshotData.outlineChapterLinks,
          );
          if (timelineXml != null) buffer.writeln(timelineXml);
        }

        if (selectedModules.contains("WorldSettings")) {
          final xml = WorldSettingsCodec.saveXML(
            snapshotData.worldSettingsData,
          );
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("Characters")) {
          final xml = CharacterCodec.saveXML(snapshotData.characterData);
          if (xml != null) buffer.writeln(xml);
        }

        buffer.writeln("</Project>");
      } else {
        if (selectedModules.contains("BaseInfo")) {
          final baseInfoSnapshot =
              base_info_module.BaseInfoCodec.createSaveSnapshot(
                data: snapshotData.baseInfoData,
                contentText: snapshotData.contentText,
                updateLatestSave: false,
              );
          final xml = base_info_module.BaseInfoCodec.saveXML(
            data: snapshotData.baseInfoData,
            totalWords: snapshotData.totalWords,
            contentText: snapshotData.contentText,
            updateLatestSave: false,
            snapshot: baseInfoSnapshot,
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
            snapshotData.segmentsData,
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
            snapshotData.outlineData,
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
          final timelineXml = TimelineCodec.saveXML(
            snapshotData.timelineDocument,
            snapshotData.outlineChapterLinks,
          );
          buffer.writeln("## Timeline");
          buffer.writeln();
          if (timelineXml != null) {
            buffer.writeln("```xml");
            buffer.writeln(timelineXml);
            buffer.writeln("```");
          }
          buffer.writeln();
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("WorldSettings")) {
          final xml = WorldSettingsCodec.saveXML(
            snapshotData.worldSettingsData,
          );
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
          final xml = CharacterCodec.saveXML(snapshotData.characterData);
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

      await ref
          .read(projectFileUseCaseProvider)
          .exportText(
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
