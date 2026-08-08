import "dart:io";

import "package:flutter/services.dart";
import "package:path/path.dart" as path;
import "package:path_provider/path_provider.dart";

abstract class PaletteRepository {
  Future<String?> readUserData();

  Future<String> readSeedData();

  Future<void> writeUserData(String content);
}

class AppSupportPaletteRepository implements PaletteRepository {
  static const String fileName = "Palettes.json";
  static const String assetPath = "assets/jsons/palettes.json";

  Future<File> _userFile() async {
    final Directory appDirectory = await getApplicationSupportDirectory();
    final Directory dataDirectory = Directory(
      path.join(appDirectory.path, "Data"),
    );
    if (!await dataDirectory.exists()) {
      await dataDirectory.create(recursive: true);
    }
    return File(path.join(dataDirectory.path, fileName));
  }

  @override
  Future<String?> readUserData() async {
    final File file = await _userFile();
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<String> readSeedData() => rootBundle.loadString(assetPath);

  @override
  Future<void> writeUserData(String content) async {
    final File target = await _userFile();
    final File temporary = File("${target.path}.tmp");
    await temporary.writeAsString(content, flush: true);
    try {
      await temporary.rename(target.path);
    } on FileSystemException {
      await target.writeAsString(content, flush: true);
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
