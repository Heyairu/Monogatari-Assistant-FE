import "../../bin/file.dart";
import "../../domain/repositories/file_repository.dart";

export "../../domain/repositories/file_repository.dart";

class DefaultFileRepository implements FileRepository {
  @override
  Future<ProjectFile> createNewProject() {
    return FileService.createNewProject();
  }

  @override
  Future<ProjectFile?> openProject() {
    return FileService.openProject();
  }

  @override
  Future<ProjectFile> openProjectFromPath(
    String filePath, {
    String? accessToken,
  }) {
    return FileService.openProjectFromPath(filePath, accessToken: accessToken);
  }

  @override
  Future<ProjectFile> saveProject(ProjectFile projectFile) {
    return FileService.saveProject(projectFile);
  }

  @override
  Future<ProjectFile> saveProjectToKnownLocation(ProjectFile projectFile) {
    return FileService.saveProjectToKnownLocation(projectFile);
  }

  @override
  Future<ProjectFile> saveProjectAs(ProjectFile projectFile) {
    return FileService.saveProjectAs(projectFile);
  }

  @override
  Future<String> saveProjectAutoBackup({
    required String projectName,
    required String content,
    required int maxTotalBytes,
  }) {
    return FileService.saveProjectAutoBackup(
      projectName: projectName,
      content: content,
      maxTotalBytes: maxTotalBytes,
    );
  }

  @override
  Future<String> getAutoBackupDirectoryPath() {
    return FileService.getAutoBackupDirectoryPath();
  }

  @override
  Future<AutoBackupDirectoryInfo> getAutoBackupDirectoryInfo() {
    return FileService.getAutoBackupDirectoryInfo();
  }

  @override
  Future<String> selectAutoBackupDirectory() {
    return FileService.selectAutoBackupDirectory();
  }

  @override
  Future<String> resetAutoBackupDirectory() {
    return FileService.resetAutoBackupDirectory();
  }

  @override
  Future<String> openAutoBackupDirectory() {
    return FileService.openAutoBackupDirectory();
  }

  @override
  Future<void> exportText({
    required String content,
    required String fileName,
    required String extension,
  }) {
    return FileService.exportText(
      content: content,
      fileName: fileName,
      extension: extension,
    );
  }

  @override
  Future<String> readLocalFile(String fileName) {
    return FileService.readLocalFile(fileName);
  }

  @override
  Future<void> writeLocalFile(String fileName, String content) {
    return FileService.writeLocalFile(fileName, content);
  }

  @override
  Future<String> getAppDocumentsPath() {
    return FileService.getAppDocumentsPath();
  }

  @override
  Future<bool> fileExists(String filePath) {
    return FileService.fileExists(filePath);
  }

  @override
  Future<void> deleteFile(String filePath) {
    return FileService.deleteFile(filePath);
  }

  @override
  Future<FileInfo> getFileInfo(String filePath) {
    return FileService.getFileInfo(filePath);
  }

  @override
  Future<String> generateProjectXml(
    ProjectData data, {
    bool updateLatestSave = true,
  }) {
    return ProjectManager.generateProjectXML(
      data,
      updateLatestSave: updateLatestSave,
    );
  }

  @override
  Future<AutoBackupCleanupResult> clearAutoBackups() {
    return FileService.clearAutoBackups();
  }

  @override
  Future<ProjectData> loadProjectFromXml(ProjectFile projectFile) {
    return ProjectManager.loadProjectFromXML(projectFile);
  }

  @override
  Future<ProjectParseResult> loadProjectParseResultFromXml(
    ProjectFile projectFile,
  ) {
    return ProjectManager.loadProjectParseResultFromXML(projectFile);
  }
}
