import "../../bin/file.dart";
import "../../data/repositories/file_repository.dart";

class ProjectFileUseCase {
  final FileRepository fileRepository;

  const ProjectFileUseCase({required this.fileRepository});

  Future<ProjectFile> createNewProject() {
    return fileRepository.createNewProject();
  }

  Future<ProjectFile?> openProject() {
    return fileRepository.openProject();
  }

  Future<ProjectFile> openProjectFromPath(
    String filePath, {
    String? accessToken,
  }) {
    return fileRepository.openProjectFromPath(
      filePath,
      accessToken: accessToken,
    );
  }

  Future<ProjectFile> saveProject(ProjectFile projectFile) {
    return fileRepository.saveProject(projectFile);
  }

  Future<ProjectFile> saveProjectToKnownLocation(ProjectFile projectFile) {
    return fileRepository.saveProjectToKnownLocation(projectFile);
  }

  Future<ProjectFile> saveProjectAs(ProjectFile projectFile) {
    return fileRepository.saveProjectAs(projectFile);
  }

  Future<String> saveProjectAutoBackup({
    required String projectName,
    required String content,
    required int maxTotalBytes,
  }) {
    return fileRepository.saveProjectAutoBackup(
      projectName: projectName,
      content: content,
      maxTotalBytes: maxTotalBytes,
    );
  }

  Future<String> getAutoBackupDirectoryPath() {
    return fileRepository.getAutoBackupDirectoryPath();
  }

  Future<AutoBackupDirectoryInfo> getAutoBackupDirectoryInfo() {
    return fileRepository.getAutoBackupDirectoryInfo();
  }

  Future<String> selectAutoBackupDirectory() {
    return fileRepository.selectAutoBackupDirectory();
  }

  Future<String> resetAutoBackupDirectory() {
    return fileRepository.resetAutoBackupDirectory();
  }

  Future<String> openAutoBackupDirectory() {
    return fileRepository.openAutoBackupDirectory();
  }

  Future<void> exportText({
    required String content,
    required String fileName,
    required String extension,
  }) {
    return fileRepository.exportText(
      content: content,
      fileName: fileName,
      extension: extension,
    );
  }

  Future<String> generateProjectXml(
    ProjectData data, {
    bool updateLatestSave = true,
  }) {
    return fileRepository.generateProjectXml(
      data,
      updateLatestSave: updateLatestSave,
    );
  }

  Future<AutoBackupCleanupResult> clearAutoBackups() {
    return fileRepository.clearAutoBackups();
  }

  Future<ProjectData> loadProjectFromXml(ProjectFile projectFile) {
    return fileRepository.loadProjectFromXml(projectFile);
  }

  Future<ProjectParseResult> loadProjectParseResultFromXml(
    ProjectFile projectFile,
  ) {
    return fileRepository.loadProjectParseResultFromXml(projectFile);
  }
}
