import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monogatari_assistant/bin/file.dart';
import 'package:monogatari_assistant/data/repositories/file_repository.dart';
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
      ProjectParseResult(projectVersion: '0.1.0', data: ProjectData.empty()),
    );
    await loadFuture;

    final finishedStatus = container
        .read(projectIoControllerProvider)
        .valueOrNull;
    expect(finishedStatus?.isParsing, false);
    expect(finishedStatus?.isBusy, false);
    expect(container.read(editorCoordinatorProvider).isLoading, false);
  });

  test('saveProjectAutoBackup skips write when content matches last backup', () async {
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
          lastAutoBackupContent: repository.generatedXml,
        );

    expect(result.wasWritten, false);
    expect(result.path, isNull);
    expect(result.content, repository.generatedXml);
    expect(repository.autoBackupWriteCount, 0);
    expect(repository.lastGenerateProjectXmlUpdateLatestSave, false);
    expect(
      container.read(projectIoControllerProvider).valueOrNull?.isBusy,
      false,
    );
  });

  test('saveProjectAutoBackup writes when content differs from last backup', () async {
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
          lastAutoBackupContent: '<Project>previous</Project>',
        );

    expect(result.wasWritten, true);
    expect(result.path, 'AutoBackup/test.mnproj');
    expect(result.content, repository.generatedXml);
    expect(repository.autoBackupWriteCount, 1);
    expect(repository.lastAutoBackupProjectName, 'test');
    expect(repository.lastAutoBackupContent, repository.generatedXml);
    expect(repository.lastGenerateProjectXmlUpdateLatestSave, false);
  });
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
    throw UnimplementedError();
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
  Future<ProjectData> loadProjectFromXml(ProjectFile projectFile) {
    throw UnimplementedError();
  }

  @override
  Future<ProjectParseResult> loadProjectParseResultFromXml(
    ProjectFile projectFile,
  ) {
    if (!loadStarted.isCompleted) {
      loadStarted.complete(projectFile);
    }
    return loadCompleter.future;
  }
}
