import "../../bin/file.dart";

abstract class GlossaryRepository {
  Future<String?> readGlossary(String fileName);

  Future<void> writeGlossary(String fileName, String content);
}

class LocalFileGlossaryRepository implements GlossaryRepository {
  @override
  Future<String?> readGlossary(String fileName) async {
    try {
      return await FileService.readLocalFile(fileName);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeGlossary(String fileName, String content) {
    return FileService.writeLocalFile(fileName, content);
  }
}
