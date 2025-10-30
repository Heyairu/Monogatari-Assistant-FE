import "dart:io";
import "dart:convert";
import "package:file_picker/file_picker.dart";
import "package:path_provider/path_provider.dart";
import "package:path/path.dart" as path;

/// 檔案操作服務類
class FileService {
  static const String defaultFileName = "MonogatariProject";
  static const String projectExtension = ".mnproj"; // MonogatariAssistant 專案檔案
  static const String textExtension = ".txt";
  static const String markdownExtension = ".md";

  /// 創建新專案
  static Future<ProjectFile> createNewProject() async {
    return ProjectFile(
      fileName: defaultFileName,
      filePath: null,
      content: _generateDefaultProjectXML(),
    );
  }

  /// 開啟專案檔案
  static Future<ProjectFile?> openProject() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["mnproj", "mga", "xml", "txt"], // 支援新舊格式
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        final content = utf8.decode(file.bytes!);
        
        return ProjectFile(
          fileName: file.name,
          filePath: file.path,
          content: content,
        );
      }
    } catch (e) {
      throw FileException("開啟檔案失敗: ${e.toString()}");
    }
    return null;
  }

  /// 儲存專案檔案
  static Future<ProjectFile> saveProject(ProjectFile projectFile) async {
    try {
      if (projectFile.filePath != null) {
        // 儲存到現有路徑
        await _writeToFile(projectFile.filePath!, projectFile.content);
        return projectFile;
      } else {
        // 另存新檔
        return await saveProjectAs(projectFile);
      }
    } catch (e) {
      throw FileException("儲存檔案失敗: ${e.toString()}");
    }
  }

  /// 另存新檔
  static Future<ProjectFile> saveProjectAs(ProjectFile projectFile) async {
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: "儲存專案檔案",
        fileName: "${projectFile.fileName}$projectExtension",
        type: FileType.custom,
        allowedExtensions: ["mnproj"],
      );

      // 如果使用者取消儲存，FilePicker 會回傳 null，處理此情況以符合 null-safety
      if (outputFile == null) {
        // 保持原樣並拋出例外或回傳原檔案，這裡選擇拋出以通知呼叫端儲存已取消
        throw FileException("另存檔案已取消");
      }

      await _writeToFile(outputFile, projectFile.content);
      
      return ProjectFile(
        fileName: path.basenameWithoutExtension(outputFile),
        filePath: outputFile,
        content: projectFile.content,
      );
        } catch (e) {
      throw FileException("另存檔案失敗: ${e.toString()}");
    }
  }

  /// 匯出文字檔案
  static Future<void> exportText({
    required String content,
    required String fileName,
    required String extension,
  }) async {
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: "匯出文字檔案",
        fileName: "$fileName$extension",
        type: FileType.custom,
        allowedExtensions: [extension.substring(1)], // 移除點號
      );
      // 處理使用者取消或未選擇路徑的情況
      if (outputFile == null) return;

      String exportContent = content;
      
      // 如果是 Markdown 格式，進行簡單的格式化
      if (extension == markdownExtension) {
        exportContent = _formatAsMarkdown(content);
      }
      
      await _writeToFile(outputFile, exportContent);
        } catch (e) {
      throw FileException("匯出檔案失敗: ${e.toString()}");
    }
  }

  /// 讀取本地檔案（用於應用程式內部儲存）
  static Future<String> readLocalFile(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(path.join(directory.path, fileName));
      
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        return "";
      }
    } catch (e) {
      throw FileException("讀取本地檔案失敗: ${e.toString()}");
    }
  }

  /// 寫入本地檔案（用於應用程式內部儲存）
  static Future<void> writeLocalFile(String fileName, String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(content);
    } catch (e) {
      throw FileException("寫入本地檔案失敗: ${e.toString()}");
    }
  }

  /// 獲取應用程式文件目錄
  static Future<String> getAppDocumentsPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// 檢查檔案是否存在
  static Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// 刪除檔案
  static Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw FileException("刪除檔案失敗: ${e.toString()}");
    }
  }

  /// 獲取檔案資訊
  static Future<FileInfo> getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      
      return FileInfo(
        name: path.basename(filePath),
        path: filePath,
        size: stat.size,
        modified: stat.modified,
        created: stat.changed,
      );
    } catch (e) {
      throw FileException("獲取檔案資訊失敗: ${e.toString()}");
    }
  }

  // 私有方法

  /// 寫入檔案到指定路徑
  static Future<void> _writeToFile(String filePath, String content) async {
    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);
  }

  /// 生成預設的專案XML內容
  static String _generateDefaultProjectXML() {
    final now = DateTime.now().toIso8601String();
    
    return """<?xml version="1.0" encoding="UTF-8"?>
<Project>
<Type>
  <Name>BaseInfo</Name>
  <General>
    <BookName></BookName>
    <Author></Author>
    <Purpose></Purpose>
    <ToRecap></ToRecap>
    <StoryType></StoryType>
    <Intro></Intro>
    <LatestSave>$now</LatestSave>
  </General>
  <Tags>
  </Tags>
  <Stats>
    <TotalWords>0</TotalWords>
    <NowWords>0</NowWords>
  </Stats>
</Type>

<Type>
  <Name>ChapterSelection</Name>
  <Segment Name="第一部" UUID="${_generateUUID()}">
    <Chapter Name="第一章" UUID="${_generateUUID()}">
      <Content></Content>
    </Chapter>
  </Segment>
</Type>

<Type>
  <Name>Outline</Name>
  <Storyline>
    <StorylineName>主線劇情</StorylineName>
    <StorylineType>起</StorylineType>
    <Memo></Memo>
    <ChapterUUID>${_generateUUID()}</ChapterUUID>
  </Storyline>
</Type>

<Type>
  <Name>WorldSettings</Name>
  <Location>
    <LocalName>主要場景</LocalName>
    <Description></Description>
    <LocationUUID>${_generateUUID()}</LocationUUID>
  </Location>
</Type>

<Type>
  <Name>Characters</Name>
  <Character>
    <Name>主角</Name>
    <Description></Description>
    <CharacterUUID>${_generateUUID()}</CharacterUUID>
  </Character>
</Type>
</Project>""";
  }

  /// 簡單的UUID生成器（使用時間戳）
  static String _generateUUID() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// 將文字格式化為Markdown
  static String _formatAsMarkdown(String content) {
    // 簡單的Markdown格式化
    final lines = content.split("\n");
    final markdown = StringBuffer();
    
    for (String line in lines) {
      if (line.trim().isEmpty) {
        markdown.writeln();
      } else {
        markdown.writeln(line);
      }
    }
    
    return markdown.toString();
  }
}

/// 專案檔案資料類
class ProjectFile {
  String fileName;
  String? filePath;
  String content;
  
  ProjectFile({
    required this.fileName,
    required this.filePath,
    required this.content,
  });
  
  /// 檢查是否為新檔案（未儲存）
  bool get isNewFile => filePath == null;
  
  /// 獲取檔案名稱（不包含副檔名）
  String get nameWithoutExtension {
    if (fileName.contains(".")) {
      return path.basenameWithoutExtension(fileName);
    }
    return fileName;
  }
  
  /// 獲取完整檔案名稱（包含副檔名）
  String get fullFileName {
    if (fileName.contains(".")) {
      return fileName;
    }
    return "$fileName${FileService.projectExtension}";
  }
}

/// 檔案資訊類
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
  
  /// 獲取人類可讀的檔案大小
  String get readableSize {
    if (size < 1024) return "$size B";
    if (size < 1024 * 1024) return "${(size / 1024).toStringAsFixed(1)} KB";
    if (size < 1024 * 1024 * 1024) return "${(size / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }
}

/// 檔案操作例外類
class FileException implements Exception {
  final String message;
  
  FileException(this.message);
  
  @override
  String toString() => "FileException: $message";
}

/// XML解析工具類
class XMLParser {
  /// 從XML內容中提取特定類型的區塊
  static List<String> extractTypeBlocks(String xmlContent, String type) {
    final blocks = <String>[];
    // 更新正則表達式以匹配新格式：<Type><Name>typeName</Name>...</Type>
    final pattern = RegExp(
      "<Type>\\s*<Name>$type</Name>[\\s\\S]*?</Type>",
      multiLine: true,
    );
    final matches = pattern.allMatches(xmlContent);
    
    for (final match in matches) {
      blocks.add(match.group(0) ?? "");
    }
    
    return blocks;
  }
  
  /// 提取XML標籤內的內容
  static String? extractTagContent(String xml, String tagName) {
    final pattern = RegExp("<$tagName>(.*?)</$tagName>", dotAll: true);
    final match = pattern.firstMatch(xml);
    return match?.group(1)?.trim();
  }
  
  /// 提取XML標籤的屬性值
  static String? extractAttribute(String xml, String tagName, String attrName) {
    final pattern = RegExp('<$tagName[^>]*\\s$attrName="([^"]*)"', dotAll: true);
    final match = pattern.firstMatch(xml);
    return match?.group(1);
  }
  
  /// 檢查XML是否包含指定的類型區塊
  static bool hasTypeBlock(String xmlContent, String type) {
    return xmlContent.contains("<Name>$type</Name>");
  }
}