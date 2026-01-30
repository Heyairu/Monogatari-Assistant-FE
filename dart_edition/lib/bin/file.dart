/*
 * ものがたり·アシスタント - Monogatari Assistant
 * Copyright (c) 2025 Heyairu（部屋伊琉）
 *
 * Licensed under the Business Source License 1.1 (Modified).
 * You may not use this file except in compliance with the License.
 * Change Date: 2030-11-04 05:14 a.m. (UTC+8)
 * Change License: Apache License 2.0
 *
 * Commercial use allowed under conditions described in Section 1;
 */

import "dart:io";
import "dart:convert";
import "package:flutter/material.dart";
import "package:file_picker/file_picker.dart";
import "package:path_provider/path_provider.dart";
import "package:path/path.dart" as path;
import "package:xml/xml.dart" as xml;

import "../modules/baseinfoview.dart" as BaseInfoModule;
import "../modules/chapterselectionview.dart" as ChapterModule;
import "../modules/outlineview.dart" as OutlineModule;
import "../modules/worldsettingsview.dart";
import "../modules/characterview.dart";

// MARK: - 1. IO (Input/Output)
/// 負責底層磁碟讀寫操作
class _FileIO {
  /// 寫入檔案
  static Future<void> write(String filePath, String content) async {
    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);
  }

  /// 讀取檔案
  static Future<String> read(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.readAsString();
    }
    return "";
  }

  /// 檢查存在
  static Future<bool> exists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// 刪除
  static Future<void> delete(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

// MARK: - 2. System Calls (系統調用)
/// 負責與作業系統交互 (Dialogs, Path Providers, File Info)
class _SystemBridge {
  /// 選擇專案檔案並讀取內容 (因為 FilePicker 在某些平台直接給 bytes)
  static Future<({String name, String? path, String content})?> pickProjectFile() async {
    FilePickerResult? result;
    
    if (Platform.isAndroid) {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
    } else {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["mnproj", "xml", "txt"],
        withData: true,
      );
    }

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      final content = utf8.decode(file.bytes!);
      return (name: file.name, path: file.path, content: content);
    }
    return null;
  }

  /// 顯示儲存專案對話框
  static Future<String?> saveProjectFileDialog({required String defaultName, required String content}) async {
    if (Platform.isAndroid) {
      return await FilePicker.platform.saveFile(
        dialogTitle: "儲存專案檔案",
        fileName: defaultName,
        type: FileType.any,
        bytes: utf8.encode(content),
      );
    } else {
      return await FilePicker.platform.saveFile(
        dialogTitle: "儲存專案檔案",
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ["mnproj"],
        bytes: utf8.encode(content),
      );
    }
  }

  /// 顯示匯出對話框
  static Future<String?> saveExportDialog({
    required String defaultName,
    required String extension,
    required String content
  }) async {
    return await FilePicker.platform.saveFile(
      dialogTitle: "匯出文字檔案",
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: [extension.substring(1)], // 移除點號
      bytes: utf8.encode(content),
    );
  }

  /// 獲取文件目錄
  static Future<String> getAppDocumentsPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// 獲取檔案系統統計資訊
  static Future<FileInfo> getFileInfo(String filePath) async {
    final file = File(filePath);
    final stat = await file.stat();
    
    return FileInfo(
      name: path.basename(filePath),
      path: filePath,
      size: stat.size,
      modified: stat.modified,
      created: stat.changed,
    );
  }
}

// MARK: - 3. Process Calls (程式調用)
/// 負責高層邏輯控制與狀態管理，連接 UI 與底層服務
class ProjectManager {
  /// 標記內容已修改 (需配合 setState 使用)
  static bool markAsModified() {
    return true; // 返回新的 hasUnsavedChanges 狀態 (true)
  }
  
  /// 標記內容已儲存 (需配合 setState 使用)
  static bool markAsSaved() {
    return false; // 返回新的 hasUnsavedChanges 狀態 (false)
  }
  
  /// 檢查是否有未儲存的變更
  static bool hasUnsavedChanges(bool hasUnsavedChanges, ProjectFile? currentProject) {
    if (currentProject == null) return false;
    return hasUnsavedChanges;
  }

  /// 同步編輯器內容到選中的章節
  static void syncEditorToSelectedChapter({
    required List<ChapterModule.SegmentData> segmentsData,
    required String? selectedSegID,
    required String? selectedChapID,
    required TextEditingController textController,
    required Function(String) updateContentCallback,
  }) {
    // 防呆檢查
    if (selectedSegID == null || selectedChapID == null) return;
    
    final segIndex = segmentsData.indexWhere((seg) => seg.segmentUUID == selectedSegID);
    if (segIndex != -1) {
      final chapIndex = segmentsData[segIndex].chapters.indexWhere((chap) => chap.chapterUUID == selectedChapID);
      if (chapIndex != -1) {
        final currentEditorContent = textController.text;
        segmentsData[segIndex].chapters[chapIndex].chapterContent = currentEditorContent;
        updateContentCallback(currentEditorContent);
      }
    }
  }

  /// 生成專案XML內容
  static String generateProjectXML(ProjectData data) {
    return FileService.generateProjectXML(data);
  }

  /// 從XML載入專案
  static Future<ProjectData> loadProjectFromXML(ProjectFile projectFile) async {
    try {
      return FileService.parseProjectXML(projectFile.content);
    } catch (e) {
      throw FileException("解析專案檔案失敗：${e.toString()}");
    }
  }

  /// 顯示儲存確認對話框
  static Future<bool?> showSaveConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool showDontShowAgain = false,
    required Function(bool) onDontShowAgainChanged,
    required Function() onSave,
  }) async {
    bool dontShowAgain = false;
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Text(title),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(message),
                  if (showDontShowAgain) ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: dontShowAgain,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          dontShowAgain = value ?? false;
                        });
                      },
                      title: const Text("以後不再提示"),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(null); // 取消
                  },
                  child: const Text("取消"),
                ),
                TextButton(
                  onPressed: () async {
                    if (showDontShowAgain && dontShowAgain) {
                      await onDontShowAgainChanged(true);
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop(true); // 不儲存，直接繼續
                    }
                  },
                  child: Text(
                    "不儲存",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () async {
                    if (showDontShowAgain && dontShowAgain) {
                      await onDontShowAgainChanged(true);
                    }
                    
                    await onSave();
                    
                    if (context.mounted) {
                      Navigator.of(context).pop(false); // 儲存後繼續
                    }
                  },
                  child: const Text("儲存"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 處理退出
  static Future<bool> handleExit(
    BuildContext context, {
    required bool showExitWarning,
    required bool hasUnsavedChanges,
    required Function(bool) onDontShowAgainChanged,
    required Function() onSave,
  }) async {
    if (!showExitWarning && !hasUnsavedChanges) {
      return true;
    }
    
    final result = await showSaveConfirmDialog(
      context,
      title: "未儲存的變更",
      message: "您有未儲存的變更，是否要在退出前儲存？",
      showDontShowAgain: true,
      onDontShowAgainChanged: onDontShowAgainChanged,
      onSave: onSave,
    );
    
    // null = 取消, true = 不儲存, false = 已儲存
    if (result == null) {
      return false; // 取消退出
    } else {
      return true; // 允許退出
    }
  }

  // Operation Actions (New, Open, Save, Export)

  static Future<void> newProject(
    BuildContext context, {
    required bool hasUnsavedChanges,
    required Function(bool) setLoading,
    required Function(String) onSuccess,
    required Function(String) onError,
    required Function(ProjectFile, ProjectData) onProjectLoaded,
    required Function() onSave,
  }) async {
    if (hasUnsavedChanges) {
      final shouldProceed = await showSaveConfirmDialog(
        context,
        title: "建立新專案",
        message: "您有未儲存的變更，是否要在建立新專案前儲存？",
        onDontShowAgainChanged: (_) {},
        onSave: onSave,
      );
      
      if (shouldProceed == null) return;
    }
    
    try {
      setLoading(true);
      final newProject = await FileService.createNewProject();
      final newData = ProjectData.empty();
      onProjectLoaded(newProject, newData);
      setLoading(false);
      onSuccess("新專案建立成功！");
    } catch (e) {
      setLoading(false);
      onError("建立新專案失敗：${e.toString()}");
    }
  }

  static Future<void> openProject(
    BuildContext context, {
    required bool hasUnsavedChanges,
    required Function(bool) setLoading,
    required Function(String) onSuccess,
    required Function(String) onError,
    required Function(ProjectFile, ProjectData) onProjectLoaded,
    required Function() onSave,
  }) async {
    if (hasUnsavedChanges) {
      final shouldProceed = await showSaveConfirmDialog(
        context,
        title: "開啟專案",
        message: "您有未儲存的變更，是否要在開啟新專案前儲存？",
        onDontShowAgainChanged: (_) {},
        onSave: onSave,
      );
      if (shouldProceed == null) return;
    }
    
    try {
      setLoading(true);
      final projectFile = await FileService.openProject();
      if (projectFile != null) {
        final data = await loadProjectFromXML(projectFile);
        onProjectLoaded(projectFile, data);
        onSuccess("專案開啟成功：${projectFile.nameWithoutExtension}");
      }
    } catch (e) {
      onError("開啟專案失敗：${e.toString()}");
    } finally {
      setLoading(false);
    }
  }

  static Future<void> saveProject(
    BuildContext context, {
    required ProjectFile? currentProject,
    required ProjectData currentData,
    required Function(bool) setLoading,
    required Function(String) onSuccess,
    required Function(String) onError,
    required Function(ProjectFile) onProjectSaved,
  }) async {
    try {
      setLoading(true);
      
      if (currentProject == null) {
        await saveProjectAs(
           context, 
           currentProject: currentProject, 
           currentData: currentData, 
           setLoading: setLoading, 
           onSuccess: onSuccess, 
           onError: onError, 
           onProjectSaved: onProjectSaved
        );
        return;
      }
      
      final xmlContent = generateProjectXML(currentData);
      currentProject.content = xmlContent;
      
      final savedProject = await FileService.saveProject(currentProject);
      onProjectSaved(savedProject);
      setLoading(false);
      onSuccess("專案儲存成功！");
    } catch (e) {
      setLoading(false);
      onError("儲存專案失敗：${e.toString()}");
    }
  }

  static Future<void> saveProjectAs(
    BuildContext context, {
    required ProjectFile? currentProject,
    required ProjectData currentData,
    required Function(bool) setLoading,
    required Function(String) onSuccess,
    required Function(String) onError,
    required Function(ProjectFile) onProjectSaved,
  }) async {
    try {
      setLoading(true);
      
      final projectToSave = currentProject ?? await FileService.createNewProject();
      
      final xmlContent = generateProjectXML(currentData);
      projectToSave.content = xmlContent;
      
      final savedProject = await FileService.saveProjectAs(projectToSave);
      onProjectSaved(savedProject);
      setLoading(false);
      onSuccess("專案另存成功：${savedProject.nameWithoutExtension}");
    } catch (e) {
      setLoading(false);
      onError("另存專案失敗：${e.toString()}");
    }
  }

  static Future<void> exportAs(
    BuildContext context, {
    required String extension,
    required ProjectData currentData,
    required String defaultFileName,
    required Function(bool) setLoading,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      setLoading(true);
      
      final buffer = StringBuffer();
      for (final segment in currentData.segmentsData) {
        buffer.writeln("# ${segment.segmentName}");
        buffer.writeln();
        for (final chapter in segment.chapters) {
          buffer.writeln("## ${chapter.chapterName}");
          buffer.writeln();
          buffer.writeln(chapter.chapterContent);
          buffer.writeln();
        }
      }
      
      await FileService.exportText(
        content: buffer.toString(),
        fileName: defaultFileName,
        extension: extension == "txt" ? ".txt" : ".md",
      );
      
      setLoading(false);
      onSuccess("匯出 $extension 檔案成功！");
    } catch (e) {
      setLoading(false);
      onError("匯出檔案失敗：${e.toString()}");
    }
  }
}

// MARK: - 4. Data Structures (資料結構)
class ProjectData {
  BaseInfoModule.BaseInfoData baseInfoData;
  List<ChapterModule.SegmentData> segmentsData;
  List<OutlineModule.StorylineData> outlineData;
  List<LocationData> worldSettingsData;
  Map<String, Map<String, dynamic>> characterData;
  
  // 狀態變數（需要被保存或重建的）
  int totalWords;
  String contentText;
  
  // 標記數據是否已被修改
  bool isDirty;
  
  ProjectData({
    required this.baseInfoData,
    required this.segmentsData,
    required this.outlineData,
    required this.worldSettingsData,
    required this.characterData,
    this.totalWords = 0,
    this.contentText = "",
    this.isDirty = false,
  });

  /// 建立一個空的專案資料
  factory ProjectData.empty() {
    return ProjectData(
      baseInfoData: BaseInfoModule.BaseInfoData(),
      segmentsData: [
        ChapterModule.SegmentData(
          segmentName: "Seg 1",
          chapters: [ChapterModule.ChapterData(chapterName: "Chapter 1", chapterContent: "")],
        )
      ],
      outlineData: [
        OutlineModule.StorylineData(
          storylineName: "序章",
          storylineType: "開場",
          scenes: [],
          memo: ""
        )
      ],
      worldSettingsData: [LocationData(localName: "主要場景")],
      characterData: {},
      totalWords: 0,
      contentText: "",
      isDirty: false,
    );
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

// MARK: - 5. Parsing (解析)
/// 負責將 XML 字串解析為資料結構
class _ProjectParser {
  static ProjectData parseProjectXML(String xmlContent) {
    // 準備載入的數據 - 使用 ProjectData.empty() 作為預設值
    final defaultData = ProjectData.empty();
    
    BaseInfoModule.BaseInfoData? loadedBaseInfo;
    List<ChapterModule.SegmentData>? loadedSegments;
    List<OutlineModule.StorylineData>? loadedOutline;
    List<LocationData>? loadedWorldSettings;
    Map<String, Map<String, dynamic>>? loadedCharacterData;
    
    // 計算 contentText 和 totalWords
    String contentText = "";
    int totalWords = 0;
    
    try {
      final document = xml.XmlDocument.parse(xmlContent);
      
      // 尋找所有的 Type 區塊
      final typeElements = document.findAllElements("Type");
      
      for (final element in typeElements) {
        // 檢查 Name 標籤確認區塊類型
        final nameElement = element.findElements("Name").firstOrNull;
        if (nameElement == null) continue;
        
        final typeName = nameElement.innerText;
        // 重新序列化為XML字串以供各模組的解析器使用
        final blockXml = element.toXmlString();
        
        try {
          switch (typeName) {
            case "BaseInfo":
              // 避免重複載入，只取第一個遇到的有效區塊
              loadedBaseInfo ??= BaseInfoModule.BaseInfoCodec.loadXML(blockXml);
              break;
              
            case "ChapterSelection":
              loadedSegments ??= ChapterModule.ChapterSelectionCodec.loadXML(blockXml);
              break;
              
            case "Outline":
              loadedOutline ??= OutlineModule.OutlineCodec.loadXML(blockXml);
              break;
              
            case "WorldSettings":
              loadedWorldSettings ??= WorldSettingsCodec.loadXML(blockXml);
              break;
              
            case "Characters":
              loadedCharacterData ??= CharacterCodec.loadXML(blockXml);
              break;
          }
        } catch (e) {
          debugPrint("解析 $typeName 區塊時發生錯誤: $e");
          // 繼續解析其他區塊
        }
      }
    } catch (e) {
      debugPrint("XML 解析失敗: $e");
      // 如果 XML 格式完全錯誤，將回傳預設的空專案
    }
    
    // 如果有載入章節數據，使用第一個章節的內容
    final targetSegments = loadedSegments ?? defaultData.segmentsData;
    if (targetSegments.isNotEmpty && targetSegments[0].chapters.isNotEmpty) {
      contentText = targetSegments[0].chapters[0].chapterContent;
      // 簡單的字數統計
      totalWords = contentText.split(RegExp(r"\s+")).where((word) => word.isNotEmpty).length;
    }
    
    return ProjectData(
      baseInfoData: loadedBaseInfo ?? defaultData.baseInfoData,
      segmentsData: loadedSegments ?? defaultData.segmentsData,
      outlineData: loadedOutline ?? defaultData.outlineData,
      worldSettingsData: loadedWorldSettings ?? defaultData.worldSettingsData,
      characterData: loadedCharacterData ?? defaultData.characterData,
      totalWords: totalWords,
      contentText: contentText,
    );
  }
}

// MARK: - 6. Merging (合併)
/// 負責將資料結構合併/生成為 XML 或其他格式
class _ProjectMerger {
  /// 生成專案XML內容
  static String generateProjectXML(ProjectData data) {
    final buffer = StringBuffer();
    
    buffer.writeln("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
    buffer.writeln("<Project>");
    
    // BaseInfo
    final baseInfoXml = BaseInfoModule.BaseInfoCodec.saveXML(
      data: data.baseInfoData,
      totalWords: data.totalWords,
      contentText: data.contentText,
    );
    if (baseInfoXml != null) {
      buffer.writeln(baseInfoXml);
    }
    
    // ChapterSelection
    final chapterXml = ChapterModule.ChapterSelectionCodec.saveXML(data.segmentsData);
    if (chapterXml != null) {
      buffer.writeln(chapterXml);
    }
    
    // Outline
    final outlineXml = OutlineModule.OutlineCodec.saveXML(data.outlineData);
    if (outlineXml != null) {
      buffer.writeln(outlineXml);
    }
    
    // WorldSettings
    final worldXml = WorldSettingsCodec.saveXML(data.worldSettingsData);
    if (worldXml != null) {
      buffer.writeln();
      buffer.write(worldXml);
    }
    
    // Characters
    final characterXml = CharacterCodec.saveXML(data.characterData);
    if (characterXml != null) {
      buffer.writeln();
      buffer.write(characterXml);
    }
    
    buffer.writeln("</Project>");
    
    return buffer.toString();
  }

  /// 將文字格式化為Markdown
  static String formatAsMarkdown(String content) {
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

// MARK: - 7. Interface (介面)
// 負責協調 IO、System、Parsing、Merging 四大模組

class FileService {
  static const String defaultFileName = "MonogatariProject";
  static const String projectExtension = ".mnproj"; // MonogatariAssistant 專案檔案
  static const String textExtension = ".txt";
  static const String markdownExtension = ".md";

  // --- 專案生命週期 ---

  /// 創建新專案
  static Future<ProjectFile> createNewProject() async {
    return ProjectFile(
      fileName: defaultFileName,
      filePath: null,
      content: generateProjectXML(ProjectData.empty()),
    );
  }

  /// 開啟專案檔案
  static Future<ProjectFile?> openProject() async {
    try {
      final result = await _SystemBridge.pickProjectFile();
      if (result != null) {
        return ProjectFile(
          fileName: result.name,
          filePath: result.path,
          content: result.content,
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
        await _FileIO.write(projectFile.filePath!, projectFile.content);
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
      final outputFile = await _SystemBridge.saveProjectFileDialog(
        defaultName: "${projectFile.fileName}$projectExtension",
        content: projectFile.content,
      );

      // 如果使用者取消儲存
      if (outputFile == null) {
        throw FileException("另存檔案已取消");
      }

      // 在桌面平台上仍需要寫入檔案 (SystemBridge 可能只回傳路徑)
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await _FileIO.write(outputFile, projectFile.content);
      }
      
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
      String exportContent = content;
      
      // 如果是 Markdown 格式，進行簡單的格式化
      if (extension == markdownExtension) {
        exportContent = _ProjectMerger.formatAsMarkdown(content);
      }

      final outputFile = await _SystemBridge.saveExportDialog(
        defaultName: "$fileName$extension",
        extension: extension,
        content: exportContent, // 傳遞內容以供某些平台 direct save
      );
      
      if (outputFile == null) return;
      
      // 在桌面平台上仍需要寫入檔案
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await _FileIO.write(outputFile, exportContent);
      }
    } catch (e) {
      throw FileException("匯出檔案失敗: ${e.toString()}");
    }
  }

  // --- 本地檔案操作 ---

  /// 讀取本地檔案（用於應用程式內部儲存）
  static Future<String> readLocalFile(String fileName) async {
    try {
      final dirPath = await _SystemBridge.getAppDocumentsPath();
      final fullPath = path.join(dirPath, fileName);
      return await _FileIO.read(fullPath);
    } catch (e) {
      throw FileException("讀取本地檔案失敗: ${e.toString()}");
    }
  }

  /// 寫入本地檔案（用於應用程式內部儲存）
  static Future<void> writeLocalFile(String fileName, String content) async {
    try {
      final dirPath = await _SystemBridge.getAppDocumentsPath();
      final fullPath = path.join(dirPath, fileName);
      await _FileIO.write(fullPath, content);
    } catch (e) {
      throw FileException("寫入本地檔案失敗: ${e.toString()}");
    }
  }

  // --- 系統資訊與管理 ---

  /// 獲取應用程式文件目錄
  static Future<String> getAppDocumentsPath() async {
    return _SystemBridge.getAppDocumentsPath();
  }

  /// 檢查檔案是否存在
  static Future<bool> fileExists(String filePath) async {
    return _FileIO.exists(filePath);
  }

  /// 刪除檔案
  static Future<void> deleteFile(String filePath) async {
    try {
      await _FileIO.delete(filePath);
    } catch (e) {
      throw FileException("刪除檔案失敗: ${e.toString()}");
    }
  }

  /// 獲取檔案資訊
  static Future<FileInfo> getFileInfo(String filePath) async {
    try {
      return await _SystemBridge.getFileInfo(filePath);
    } catch (e) {
      throw FileException("獲取檔案資訊失敗: ${e.toString()}");
    }
  }

  // --- 轉換與處理 ---

  /// 生成專案XML內容 (Merger)
  static String generateProjectXML(ProjectData data) {
    return _ProjectMerger.generateProjectXML(data);
  }
  
  /// 解析專案XML內容 (Parser)
  static ProjectData parseProjectXML(String xmlContent) {
    return _ProjectParser.parseProjectXML(xmlContent);
  }
}
