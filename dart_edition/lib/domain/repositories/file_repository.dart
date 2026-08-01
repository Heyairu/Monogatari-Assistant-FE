import "../../models/project_data.dart";
import "../../models/project_file.dart";

abstract class FileRepository {
  Future<ProjectFile> createNewProject();
  Future<ProjectFile?> openProject();
  Future<ProjectFile> openProjectFromPath(
    String filePath, {
    String? accessToken,
  });
  Future<ProjectFile> saveProject(ProjectFile projectFile);
  Future<ProjectFile> saveProjectToKnownLocation(ProjectFile projectFile);
  Future<ProjectFile> saveProjectAs(ProjectFile projectFile);
  Future<String> saveProjectAutoBackup({
    required String projectName,
    required String content,
    required int maxTotalBytes,
  });
  Future<String> getAutoBackupDirectoryPath();
  Future<AutoBackupDirectoryInfo> getAutoBackupDirectoryInfo();
  Future<AutoBackupCleanupResult> clearAutoBackups();
  Future<String> selectAutoBackupDirectory();
  Future<String> resetAutoBackupDirectory();
  Future<String> openAutoBackupDirectory();
  Future<void> exportText({
    required String content,
    required String fileName,
    required String extension,
  });
  Future<String> readLocalFile(String fileName);
  Future<void> writeLocalFile(String fileName, String content);
  Future<String> getAppDocumentsPath();
  Future<bool> fileExists(String filePath);
  Future<void> deleteFile(String filePath);
  Future<FileInfo> getFileInfo(String filePath);
  Future<String> generateProjectXml(
    ProjectData data, {
    bool updateLatestSave = true,
  });
  Future<ProjectData> loadProjectFromXml(ProjectFile projectFile);
  Future<ProjectParseResult> loadProjectParseResultFromXml(
    ProjectFile projectFile,
  );
}
