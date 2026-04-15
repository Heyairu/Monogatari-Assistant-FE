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

  Future<ProjectFile> saveProjectAs(ProjectFile projectFile) {
    return fileRepository.saveProjectAs(projectFile);
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

  Future<String> generateProjectXml(ProjectData data) {
    return fileRepository.generateProjectXml(data);
  }

  Future<ProjectData> loadProjectFromXml(ProjectFile projectFile) {
    return fileRepository.loadProjectFromXml(projectFile);
  }
}
