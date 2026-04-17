import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../bin/file.dart";
import "../../modules/baseinfoview.dart" as base_info_module;
import "../../modules/chapterselectionview.dart" as chapter_module;
import "../../modules/characterview.dart";
import "../../modules/outlineview.dart" as outline_module;
import "../../modules/worldsettingsview.dart";
import "core_providers.dart";
import "project_state_providers.dart";

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
  base_info_module.BaseInfoData _snapshotBaseInfo(
    base_info_module.BaseInfoData value,
  ) {
    return value.copyWith(tags: [...value.tags]);
  }

  List<chapter_module.SegmentData> _snapshotSegments(
    List<chapter_module.SegmentData> source,
  ) {
    return source
        .map(
          (segment) => segment.copyWith(
            chapters: segment.chapters
                .map((chapter) => chapter.copyWith())
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  List<outline_module.StorylineData> _snapshotOutline(
    List<outline_module.StorylineData> source,
  ) {
    return source
        .map(
          (storyline) => storyline.copyWith(
            people: [...storyline.people],
            item: [...storyline.item],
            scenes: storyline.scenes
                .map(
                  (event) => event.copyWith(
                    people: [...event.people],
                    item: [...event.item],
                    scenes: event.scenes
                        .map(
                          (scene) => scene.copyWith(
                            people: [...scene.people],
                            item: [...scene.item],
                            doingThings: [...scene.doingThings],
                          ),
                        )
                        .toList(growable: false),
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  ProjectData _snapshotProjectData(
    ProjectData source, {
    base_info_module.BaseInfoData? baseInfoOverride,
  }) {
    return ProjectData(
      baseInfoData: _snapshotBaseInfo(baseInfoOverride ?? source.baseInfoData),
      segmentsData: _snapshotSegments(source.segmentsData),
      outlineData: _snapshotOutline(source.outlineData),
      foreshadowData: source.foreshadowData,
      updatePlanData: source.updatePlanData,
      worldSettingsData: source.worldSettingsData,
      characterData: source.characterData,
      totalWords: source.totalWords,
      contentText: source.contentText,
      isDirty: source.isDirty,
    );
  }

  @override
  Future<ProjectIoStatus> build() async {
    return const ProjectIoStatus.idle();
  }

  Future<ProjectLoadResult> createNewProject() async {
    state = const AsyncLoading();
    try {
      final useCase = ref.read(projectFileUseCaseProvider);
      final projectFile = await useCase.createNewProject();
      final data = _snapshotProjectData(ProjectData.empty());
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
      final snapshot = _snapshotProjectData(data);
      state = const AsyncData(
        ProjectIoStatus(operation: ProjectIoOperation.openProject),
      );
      return snapshot;
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

      final baseInfoSnapshot =
          base_info_module.BaseInfoCodec.createSaveSnapshot(
            data: currentData.baseInfoData,
            contentText: currentData.contentText,
          );
      ref
          .read(baseInfoDataProvider.notifier)
          .updateBaseInfoData((_) => baseInfoSnapshot);

      final snapshotData = _snapshotProjectData(
        currentData,
        baseInfoOverride: baseInfoSnapshot,
      );

      final xmlContent = await useCase.generateProjectXml(snapshotData);
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
      final snapshotData = _snapshotProjectData(currentData);
      final buffer = StringBuffer();
      for (final segment in snapshotData.segmentsData) {
        buffer.writeln("# ${segment.segmentName}");
        buffer.writeln();
        for (final chapter in segment.chapters) {
          buffer.writeln("## ${chapter.chapterName}");
          buffer.writeln();
          buffer.writeln(chapter.chapterContent);
          buffer.writeln();
        }
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
    state = const AsyncLoading();
    try {
      final snapshotData = _snapshotProjectData(currentData);
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
