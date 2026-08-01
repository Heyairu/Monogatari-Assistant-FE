import "package:path/path.dart" as path;

const String projectFileExtension = ".mnproj";

class ProjectFile {
  String fileName;
  String? filePath;
  String? uri;
  String? _transientContent;

  ProjectFile({
    required this.fileName,
    required this.filePath,
    this.uri,
    required String content,
  }) : _transientContent = content.isEmpty ? null : content;

  /// One-shot transport payload. File services clear this after parse/write.
  String get content => _transientContent ?? "";

  set content(String value) {
    _transientContent = value.isEmpty ? null : value;
  }

  String takeContent() {
    final value = _transientContent ?? "";
    _transientContent = null;
    return value;
  }

  bool get isNewFile => filePath == null && uri == null;

  String get nameWithoutExtension {
    if (fileName.contains(".")) {
      return path.basenameWithoutExtension(fileName);
    }
    return fileName;
  }

  String get fullFileName {
    if (fileName.contains(".")) return fileName;
    return "$fileName$projectFileExtension";
  }
}

class FileInfo {
  final String name;
  final String path;
  final int size;
  final DateTime modified;
  final DateTime created;

  FileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
    required this.created,
  });

  String get readableSize {
    if (size < 1024) return "$size B";
    if (size < 1024 * 1024) return "${(size / 1024).toStringAsFixed(1)} KB";
    if (size < 1024 * 1024 * 1024) {
      return "${(size / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
    return "${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }
}

class AutoBackupDirectoryInfo {
  final String path;
  final bool isConfigured;
  final bool isDefault;
  final bool canReset;
  final bool isAndroid;
  final int totalBytes;
  final int fileCount;

  const AutoBackupDirectoryInfo({
    required this.path,
    required this.isConfigured,
    required this.isDefault,
    required this.canReset,
    required this.isAndroid,
    this.totalBytes = 0,
    this.fileCount = 0,
  });
}

class AutoBackupCleanupResult {
  final int deletedFiles;
  final int freedBytes;

  const AutoBackupCleanupResult({
    required this.deletedFiles,
    required this.freedBytes,
  });
}

class FileException implements Exception {
  final String message;

  FileException(this.message);

  @override
  String toString() => "FileException: $message";
}
