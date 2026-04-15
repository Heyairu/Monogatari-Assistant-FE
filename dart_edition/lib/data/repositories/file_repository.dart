import "../../bin/file.dart";

abstract class FileRepository {
  Future<ProjectFile> createNewProject();

  Future<ProjectFile?> openProject();

  Future<ProjectFile> openProjectFromPath(String filePath, {String? accessToken});

  Future<ProjectFile> saveProject(ProjectFile projectFile);

  Future<ProjectFile> saveProjectAs(ProjectFile projectFile);

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

  Future<String> generateProjectXml(ProjectData data);

  Future<ProjectData> loadProjectFromXml(ProjectFile projectFile);
}

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
  Future<ProjectFile> saveProjectAs(ProjectFile projectFile) {
    return FileService.saveProjectAs(projectFile);
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
  Future<String> generateProjectXml(ProjectData data) {
    return ProjectManager.generateProjectXML(data);
  }

  @override
  Future<ProjectData> loadProjectFromXml(ProjectFile projectFile) {
    return ProjectManager.loadProjectFromXML(projectFile);
  }
}
