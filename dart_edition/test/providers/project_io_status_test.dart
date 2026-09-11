import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monogatari_assistant/bin/file.dart';
import 'package:monogatari_assistant/data/repositories/file_repository.dart';
import 'package:monogatari_assistant/models/chapter_selection_data.dart';
import 'package:monogatari_assistant/presentation/providers/core_providers.dart';
import 'package:monogatari_assistant/presentation/providers/editor_coordinator_provider.dart';
import 'package:monogatari_assistant/presentation/providers/project_io_providers.dart';
import 'package:monogatari_assistant/presentation/providers/project_state_providers.dart';

void main() {
  test('saveProject is operation-specific and does not block editor', () async {
    final repository = _BlockingFileRepository();
    final container = ProviderContainer(
      overrides: [fileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    expect(container.read(editorCoordinatorProvider).isLoading, false);
    expect(container.read(baseInfoDataProvider).latestSave, isNull);

    final projectFile = ProjectFile(
      fileName: 'test.mnproj',
      filePath: 'test.mnproj',
      content: '',
    );

    final saveFuture = container
        .read(projectIoControllerProvider.notifier)
        .saveProject(
          currentProject: projectFile,
          currentData: ProjectData.empty(),
          forceSaveAs: false,
        );

    await repository.saveStarted.future;

    final status = container.read(projectIoControllerProvider).valueOrNull;
    expect(status?.isSaving, true);
    expect(status?.isBusy, true);
    expect(status?.blocksEditor, false);
    expect(container.read(editorCoordinatorProvider).isLoading, false);
    expect(container.read(baseInfoDataProvider).latestSave, isNull);

    repository.saveCompleter.complete(projectFile);
    await saveFuture;

    final finishedStatus = container
        .read(projectIoControllerProvider)
        .valueOrNull;
    expect(finishedStatus?.isSaving, false);
    expect(finishedStatus?.isBusy, false);
    expect(container.read(editorCoordinatorProvider).isLoading, false);
    expect(container.read(baseInfoDataProvider).latestSave, isNull);
  });

  test('loadProject parsing blocks editor until data is loaded', () async {
    const sourceProjectUuid = '123e4567-e89b-42d3-a456-426614174000';
    final repository = _BlockingFileRepository();
    final container = ProviderContainer(
      overrides: [fileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    expect(container.read(editorCoordinatorProvider).isLoading, false);

    final projectFile = ProjectFile(
      fileName: 'test.mnproj',
      filePath: 'test.mnproj',
      content: '<Project />',
    );

    final loadFuture = container
        .read(projectIoControllerProvider.notifier)
        .loadProject(projectFile);

    await repository.loadStarted.future;

    final status = container.read(projectIoControllerProvider).valueOrNull;
    expect(status?.isParsing, true);
    expect(status?.isBusy, true);
    expect(status?.blocksEditor, true);
    expect(container.read(editorCoordinatorProvider).isLoading, true);

    repository.loadCompleter.complete(
      ProjectParseResult(
        projectVersion: '0.1.0',
        sourceProjectUuid: sourceProjectUuid,
        data: ProjectData.empty(projectUUID: sourceProjectUuid),
      ),
    );
    final loadResult = await loadFuture;

    final finishedStatus = container
        .read(projectIoControllerProvider)
        .valueOrNull;
    expect(finishedStatus?.isParsing, false);
    expect(finishedStatus?.isBusy, false);
    expect(container.read(editorCoordinatorProvider).isLoading, false);
    expect(loadResult.persistedXmlContent, '<Project />');
    expect(loadResult.persistedProjectUuid, sourceProjectUuid);
    expect(projectFile.content, isEmpty);
  });

  test('saveProjectAutoBackup does not retain a full XML baseline', () async {
    final repository = _BlockingFileRepository();
    final container = ProviderContainer(
      overrides: [fileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(projectIoControllerProvider.notifier)
        .saveProjectAutoBackup(
          currentProject: ProjectFile(
            fileName: 'test.mnproj',
            filePath: null,
            content: '',
          ),
          currentData: ProjectData.empty(),
          maxTotalBytes: 512 * 1024 * 1024,
        );

    expect(result.wasWritten, true);
    expect(result.path, 'AutoBackup/test.mnproj');
    expect(repository.autoBackupWriteCount, 1);
    expect(repository.lastGenerateProjectXmlUpdateLatestSave, true);
    expect(
      container.read(projectIoControllerProvider).valueOrNull?.isBusy,
      false,
    );
  });

  test('saveProjectAutoBackup writes the generated payload', () async {
    final repository = _BlockingFileRepository()
      ..generatedXml = '<Project>changed</Project>';
    final container = ProviderContainer(
      overrides: [fileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(projectIoControllerProvider.notifier)
        .saveProjectAutoBackup(
          currentProject: ProjectFile(
            fileName: 'test.mnproj',
            filePath: null,
            content: '',
          ),
          currentData: ProjectData.empty(),
          maxTotalBytes: 512 * 1024 * 1024,
        );

    expect(result.wasWritten, true);
    expect(result.path, 'AutoBackup/test.mnproj');
    expect(repository.autoBackupWriteCount, 1);
    expect(repository.lastAutoBackupProjectName, 'test');
    expect(repository.lastAutoBackupContent, repository.generatedXml);
    expect(repository.lastGenerateProjectXmlUpdateLatestSave, true);
  });

  test('save-as payload receives a new UUID without mutating source', () async {
    final repository = _BlockingFileRepository();
    final container = ProviderContainer(
      overrides: [fileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    const originalUuid = '123e4567-e89b-42d3-a456-426614174000';
    final source = ProjectData.empty(projectUUID: originalUuid);
    final controller = container.read(projectIoControllerProvider.notifier);

    final regularPayload = await controller.prepareProjectPayload(source);
    final saveAsPayload = await controller.prepareProjectPayload(
      source,
      regenerateProjectUuid: true,
    );

    expect(regularPayload.snapshot.projectUUID, originalUuid);
    expect(saveAsPayload.snapshot.projectUUID, isNot(originalUuid));
    expect(saveAsPayload.snapshot.projectUUID, isNotEmpty);
    expect(source.projectUUID, originalUuid);
  });

  test('first persistence keeps the in-memory collaboration UUID', () {
    final memoryProject = ProjectFile(
      fileName: 'memory.mnproj',
      filePath: null,
      content: '',
    );
    final persistedProject = ProjectFile(
      fileName: 'saved.mnproj',
      filePath: 'C:/projects/saved.mnproj',
      content: '',
    );

    expect(shouldRegenerateProjectUuidForSaveAs(memoryProject), isFalse);
    expect(shouldRegenerateProjectUuidForSaveAs(null), isFalse);
    expect(shouldRegenerateProjectUuidForSaveAs(persistedProject), isTrue);
  });

  test(
    'reader exports hide annotations while XML preserves raw syntax',
    () async {
      const uuid = '4e251fc2-1e2b-4f78-93da-91f8c76d9a92';
      const raw = '她看見 //@+^CE<$uuid|艾莉絲>{主角}//。';
      final repository = _BlockingFileRepository();
      final container = ProviderContainer(
        overrides: [fileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final data = ProjectData.empty()
        ..contentText = raw
        ..segmentsData = [
          SegmentData(
            segmentName: '第一卷',
            chapters: [ChapterData(chapterName: '第一章', chapterContent: raw)],
          ),
        ];
      final controller = container.read(projectIoControllerProvider.notifier);

      await controller.exportAs(
        extension: 'txt',
        currentData: data,
        defaultFileName: 'reader',
      );
      expect(repository.lastExportContent, contains('她看見 艾莉絲。'));
      expect(repository.lastExportContent, isNot(contains(uuid)));
      expect(repository.lastExportContent, isNot(contains('{主角}')));

      await controller.exportSelective(
        currentData: data,
        defaultFileName: 'reader',
        selectedModules: const {'BaseInfo', 'Chapters'},
        format: 'md',
      );
      expect(repository.lastExportContent, contains('艾莉絲'));
      expect(repository.lastExportContent, isNot(contains(uuid)));

      await controller.exportSelective(
        currentData: data,
        defaultFileName: 'archive',
        selectedModules: const {'BaseInfo', 'Chapters'},
        format: 'xml',
      );
      expect(repository.lastExportContent, contains(uuid));
      expect(repository.lastExportContent, contains('{主角}'));
    },
  );

  test(
    'verified remote snapshot overwrites only the known current location',
    () async {
      const projectUuid = '123e4567-e89b-42d3-a456-426614174000';
      const xml = '<Project UUID="$projectUuid"><ver>1.0</ver></Project>';
      final repository = _BlockingFileRepository();
      final container = ProviderContainer(
        overrides: [fileRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final current = ProjectFile(
        fileName: 'same.mnproj',
        filePath: 'C:/projects/same.mnproj',
        content: '',
      );

      final overwrite = container
          .read(projectIoControllerProvider.notifier)
          .overwriteAndLoadExternalProjectSnapshot(
            currentProject: current,
            xmlContent: xml,
          );
      await repository.loadStarted.future;
      repository.loadCompleter.complete(
        ProjectParseResult(
          projectVersion: '1.0',
          sourceProjectUuid: projectUuid,
          data: ProjectData.empty(projectUUID: projectUuid),
        ),
      );
      final written = await repository.saveStarted.future;
      expect(written.filePath, current.filePath);
      expect(written.uri, current.uri);
      expect(written.content, xml);
      repository.saveCompleter.complete(written);

      final result = await overwrite;
      expect(result.projectFile.filePath, current.filePath);
      expect(result.persistedProjectUuid, projectUuid);
      expect(result.data.projectUUID, projectUuid);
    },
  );
}

class _BlockingFileRepository implements FileRepository {
  final Completer<ProjectFile> saveStarted = Completer<ProjectFile>();
  final Completer<ProjectFile> saveCompleter = Completer<ProjectFile>();
  final Completer<ProjectFile> loadStarted = Completer<ProjectFile>();
  final Completer<ProjectParseResult> loadCompleter =
      Completer<ProjectParseResult>();
  String generatedXml = '<Project />';
  bool? lastGenerateProjectXmlUpdateLatestSave;
  int autoBackupWriteCount = 0;
  String? lastAutoBackupProjectName;
  String? lastAutoBackupContent;
  String? lastExportContent;

  @override
  Future<ProjectFile> createNewProject() {
    return Future.value(
      ProjectFile(fileName: 'new.mnproj', filePath: null, content: ''),
    );
  }

  @override
  Future<ProjectFile?> openProject() {
    throw UnimplementedError();
  }

  @override
  Future<ProjectFile> openProjectFromPath(
    String filePath, {
    String? accessToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ProjectFile> openProjectFromExternalUri(String uri) {
    throw UnimplementedError();
  }

  @override
  Future<ProjectFile> saveProject(ProjectFile projectFile) {
    if (!saveStarted.isCompleted) {
      saveStarted.complete(projectFile);
    }
    return saveCompleter.future;
  }

  @override
  Future<ProjectFile> saveProjectToKnownLocation(ProjectFile projectFile) {
    return saveProject(projectFile);
  }

  @override
  Future<ProjectFile> saveProjectAs(ProjectFile projectFile) {
    return saveProject(projectFile);
  }

  @override
  Future<String> saveProjectAutoBackup({
    required String projectName,
    required String content,
    required int maxTotalBytes,
  }) {
    autoBackupWriteCount += 1;
    lastAutoBackupProjectName = projectName;
    lastAutoBackupContent = content;
    return Future.value('AutoBackup/$projectName.mnproj');
  }

  @override
  Future<String> getAutoBackupDirectoryPath() {
    return Future.value('AutoBackup');
  }

  @override
  Future<AutoBackupDirectoryInfo> getAutoBackupDirectoryInfo() {
    return Future.value(
      const AutoBackupDirectoryInfo(
        path: 'AutoBackup',
        isConfigured: true,
        isDefault: true,
        canReset: false,
        isAndroid: false,
      ),
    );
  }

  @override
  Future<String> selectAutoBackupDirectory() {
    return Future.value('AutoBackup');
  }

  @override
  Future<String> resetAutoBackupDirectory() {
    return Future.value('AutoBackup');
  }

  @override
  Future<String> openAutoBackupDirectory() {
    return Future.value('AutoBackup');
  }

  @override
  Future<void> exportText({
    required String content,
    required String fileName,
    required String extension,
  }) {
    lastExportContent = content;
    return Future.value();
  }

  @override
  Future<String> readLocalFile(String fileName) {
    throw UnimplementedError();
  }

  @override
  Future<void> writeLocalFile(String fileName, String content) {
    throw UnimplementedError();
  }

  @override
  Future<String> getAppDocumentsPath() {
    throw UnimplementedError();
  }

  @override
  Future<bool> fileExists(String filePath) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteFile(String filePath) {
    throw UnimplementedError();
  }

  @override
  Future<FileInfo> getFileInfo(String filePath) {
    throw UnimplementedError();
  }

  @override
  Future<String> generateProjectXml(
    ProjectData data, {
    bool updateLatestSave = true,
  }) {
    lastGenerateProjectXmlUpdateLatestSave = updateLatestSave;
    return Future.value(generatedXml);
  }

  @override
  Future<AutoBackupCleanupResult> clearAutoBackups() {
    return Future.value(
      const AutoBackupCleanupResult(deletedFiles: 0, freedBytes: 0),
    );
  }

  @override
  Future<ProjectData> loadProjectFromXml(ProjectFile projectFile) {
    throw UnimplementedError();
  }

  @override
  Future<ProjectParseResult> loadProjectParseResultFromXml(
    ProjectFile projectFile,
  ) {
    projectFile.takeContent();
    if (!loadStarted.isCompleted) {
      loadStarted.complete(projectFile);
    }
    return loadCompleter.future;
  }
}
