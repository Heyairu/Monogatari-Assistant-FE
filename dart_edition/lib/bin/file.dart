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
import "package:flutter/services.dart"; // Added for MethodChannel
import "package:flutter/foundation.dart"; // Added for compute
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
  static const platform = MethodChannel("com.heyairu.monogatari_assistant/file");

  /// 寫入 URI (Android SAF)
  static Future<void> writeToUri(String uri, String content) async {
    try {
      await platform.invokeMethod("writeToUri", {
        "uri": uri,
        "content": content,
      });
    } on PlatformException catch (e) {
      throw FileException("寫入 URI 失敗: ${e.message}");
    }
  }

  /// 選擇專案檔案並讀取內容 (因為 FilePicker 在某些平台直接給 bytes)
  static Future<({String name, String? path, String? uri, String content})?> pickProjectFile() async {
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
      return (name: file.name, path: file.path, uri: file.identifier, content: content);
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
  static Future<String> generateProjectXML(ProjectData data) async {
    return compute(FileService.generateProjectXML, data);
  }

  /// 從XML載入專案
  static Future<ProjectData> loadProjectFromXML(ProjectFile projectFile) async {
    try {
      return compute(FileService.parseProjectXML, projectFile.content);
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
      
      final xmlContent = await generateProjectXML(currentData);
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
      
      final xmlContent = await generateProjectXML(currentData);
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

  static Future<void> exportSelective(
    BuildContext context, {
    required ProjectData currentData,
    required String defaultFileName,
    required Set<String> selectedModules,
    required String format, // "xml" or "md"
    required Function(bool) setLoading,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      setLoading(true);
      final buffer = StringBuffer();
      
      if (format == "xml") {
        buffer.writeln("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        buffer.writeln("<Project>");
        buffer.writeln("<ver>${FileService.projectVersion}</ver>");
        
        if (selectedModules.contains("BaseInfo")) {
          final xml = BaseInfoModule.BaseInfoCodec.saveXML(
            data: currentData.baseInfoData,
            totalWords: currentData.totalWords,
            contentText: currentData.contentText,
          );
          if (xml != null) buffer.writeln(xml);
        }
        
        if (selectedModules.contains("Chapters")) {
          final xml = ChapterModule.ChapterSelectionCodec.saveXML(currentData.segmentsData);
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("Outline")) {
          final xml = OutlineModule.OutlineCodec.saveXML(currentData.outlineData);
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("WorldSettings")) {
          final xml = WorldSettingsCodec.saveXML(currentData.worldSettingsData);
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("Characters")) {
          final xml = CharacterCodec.saveXML(currentData.characterData);
          if (xml != null) buffer.writeln(xml);
        }
        
        buffer.writeln("</Project>");
      } else {
        // Markdown
        if (selectedModules.contains("BaseInfo")) {
          buffer.writeln(_ProjectMerger.generateBaseInfoMD(currentData.baseInfoData, currentData.totalWords));
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("Chapters")) {
          buffer.writeln(_ProjectMerger.generateChapterMD(currentData.segmentsData));
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("Outline")) {
          buffer.writeln(_ProjectMerger.generateOutlineMD(currentData.outlineData));
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("WorldSettings")) {
          buffer.writeln(_ProjectMerger.generateWorldSettingsMD(currentData.worldSettingsData));
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("Characters")) {
          buffer.writeln(_ProjectMerger.generateCharacterMD(currentData.characterData));
          buffer.writeln("---");
          buffer.writeln();
        }
      }

      await FileService.exportText(
        content: buffer.toString(),
        fileName: defaultFileName,
        extension: format == "xml" ? ".xml" : ".md",
      );

      setLoading(false);
      onSuccess("匯出成功！");
    } catch (e) {
      setLoading(false);
      onError("匯出失敗：${e.toString()}");
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
  String? uri;
  String content;
  
  ProjectFile({
    required this.fileName,
    required this.filePath,
    this.uri,
    required this.content,
  });
  
  /// 檢查是否為新檔案（未儲存）
  bool get isNewFile => filePath == null && uri == null;
  
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
    buffer.writeln("<ver>${FileService.projectVersion}</ver>");
    
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

  /// 生成 BaseInfo Markdown
  static String generateBaseInfoMD(BaseInfoModule.BaseInfoData data, int totalWords) {
    final buffer = StringBuffer();
    buffer.writeln("# 故事設定 (Base Info)");
    buffer.writeln();
    buffer.writeln("- **書名**: ${data.bookName}");
    buffer.writeln("- **作者**: ${data.author}");
    buffer.writeln("- **類型**: ${data.storyType}");
    buffer.writeln("- **主旨**: ${data.purpose}");
    buffer.writeln("- **一句話簡介**: ${data.toRecap}");
    buffer.writeln("- **標籤**: ${data.tags.join(", ")}");
    buffer.writeln("- **簡介**: \n${data.intro}");
    buffer.writeln("- **總字數**: $totalWords");
    buffer.writeln();
    return buffer.toString();
  }

  /// 生成 Chapter Markdown
  static String generateChapterMD(List<ChapterModule.SegmentData> segments) {
    final buffer = StringBuffer();
    buffer.writeln("# 章節內容 (Chapters)");
    buffer.writeln();
    for (final segment in segments) {
      buffer.writeln("## ${segment.segmentName}");
      for (final chapter in segment.chapters) {
        buffer.writeln("### ${chapter.chapterName}");
        buffer.writeln(chapter.chapterContent);
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  /// 生成 Outline Markdown
  static String generateOutlineMD(List<OutlineModule.StorylineData> storylines) {
    final buffer = StringBuffer();
    buffer.writeln("# 大綱 (Outline)");
    buffer.writeln();
    for (final storyline in storylines) {
      buffer.writeln("## ${storyline.storylineName} (${storyline.storylineType})");
      if (storyline.memo.isNotEmpty) buffer.writeln("備註: ${storyline.memo}");
      if (storyline.conflictPoint.isNotEmpty) buffer.writeln("衝突點: ${storyline.conflictPoint}");
      if (storyline.people.isNotEmpty) buffer.writeln("人物: ${storyline.people.join(", ")}");
      if (storyline.item.isNotEmpty) buffer.writeln("物件: ${storyline.item.join(", ")}");
      
      buffer.writeln("### 場景列表:");
      for (final event in storyline.scenes) {
        buffer.writeln("- **${event.storyEvent}**");
        if (event.memo.isNotEmpty) buffer.writeln("  - 備註: ${event.memo}");
        if (event.conflictPoint.isNotEmpty) buffer.writeln("  - 衝突: ${event.conflictPoint}");
        if (event.people.isNotEmpty) buffer.writeln("  - 人物: ${event.people.join(", ")}");
        if (event.item.isNotEmpty) buffer.writeln("  - 物件: ${event.item.join(", ")}");
        
        for (final scene in event.scenes) {
          buffer.writeln("  - [場景] ${scene.sceneName}");
          if (scene.doingThings.isNotEmpty) buffer.writeln("    - 行動: ${scene.doingThings.join(", ")}");
          if (scene.people.isNotEmpty) buffer.writeln("    - 人物: ${scene.people.join(", ")}");
          if (scene.item.isNotEmpty) buffer.writeln("    - 物件: ${scene.item.join(", ")}");
        }
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// 生成 WorldSettings Markdown
  static String generateWorldSettingsMD(List<LocationData> locations) {
    final buffer = StringBuffer();
    buffer.writeln("# 世界設定 (World Settings)");
    buffer.writeln();
    
    void printLocation(LocationData loc, int level) {
      final indent = "  " * level;
      final bullet = "- "; // Markdown list style
      
      // Node Info
      buffer.write("$indent$bullet**${loc.localName}**");
      if (loc.localType.isNotEmpty) buffer.write(" [${loc.localType}]");
      buffer.writeln();

      // Custom Values only (Note: original note field is typically printed too, but user asked for Key-Value)
      // Including Note as well for completeness if available
      if (loc.note.isNotEmpty) {
        buffer.writeln("$indent  備註: ${loc.note.replaceAll("\n", " ")}");
      }
      
      if (loc.customVal.isNotEmpty) {
        for (final kv in loc.customVal) {
          buffer.writeln("$indent  - ${kv.key}: ${kv.val}");
        }
      }
      
      // Recursion
      for (final child in loc.child) {
        printLocation(child, level + 1);
      }
    }

    for (final loc in locations) {
      printLocation(loc, 0);
    }
    
    return buffer.toString();
  }

  /// 生成 Character Markdown
  static String generateCharacterMD(Map<String, Map<String, dynamic>> characters) {
    // Mapping keys to UI titles
    final Map<String, String> keyTitleMap = {
      // Basic Info
      "name": "姓名",
      "nickname": "暱稱",
      "age": "年齡",
      "gender": "性別",
      "occupation": "職業",
      "birthday": "生日",
      "native": "出生地",
      "live": "居住地",
      "address": "住址",
      
      // Appearance
      "height": "身高",
      "weight": "體重",
      "blood": "血型",
      "hair": "髮色",
      "eye": "瞳色",
      "skin": "膚色",
      "faceFeatures": "臉型",
      "eyeFeatures": "眼型",
      "earFeatures": "耳型",
      "noseFeatures": "鼻型",
      "mouthFeatures": "嘴型",
      "eyebrowFeatures": "眉型",
      "body": "體格",
      "dress": "服裝",

      // Story
      "intention": "故事中的動機、目標",
      
      // Personality
      "mbti": "MBTI",
      "personality": "個性",
      "language": "口頭禪、慣用語",
      "interest": "興趣",
      "habit": "習慣、癖好",
      "belief": "信仰",
      "limit": "底線",
      "future": "將來想變得如何",
      "cherish": "最珍視的事物",
      "disgust": "最厭惡的事物",
      "fear": "最害怕的事物",
      "curious": "最好奇的事物",
      "expect": "最期待的事物",
      "alignment": "陣營",
      "otherValues": "其他補充(個性)",

      // Social
      "impression": "來自他人的印象",
      "likable": "最受他人欣賞/喜愛的特點",
      "family": "簡述原生家庭",
      "otherShowLove": "其他(表達喜歡)",
      "otherGoodwill": "其他(表達好意)",
      "otherHatePeople": "其他(應對討厭的人)",
      "relationship": "戀愛關係",
      "isFindNewLove": "另尋新歡",
      "isHarem": "后宮型作品",
      "otherRelationship": "其他(戀愛關係)",

      // Other
      "originalName": "原文姓名",
      "otherText": "其他補充",
    };

    final howToShowLoveLabels = {
      "confess_directly": "直接告白",
      "give_gift": "送禮物",
      "talk_often": "常常找對方講話",
      "get_attention": "做些小動作引起注意",
      "watch_silently": "默默關注對方",
    };
    final howToShowGoodwillLabels = {
      "smile": "微笑",
      "greet_actively": "主動打招呼",
      "help_actively": "主動幫忙",
      "give_small_gift": "送小禮物",
      "invite": "邀請對方",
      "share_things": "分享自己的事",
    };
    final handleHatePeopleLabels = {
      "ignore_directly": "直接無視",
      "keep_distance": "保持距離",
      "be_polite": "禮貌應對",
      "sarcastic": "冷嘲熱諷",
      "confront": "正面衝突",
      "ask_for_help": "找人幫忙",
    };

    final buffer = StringBuffer();
    buffer.writeln("# 角色設定 (Characters)");
    buffer.writeln();

    characters.forEach((id, charData) {
      buffer.writeln("## ${charData["name"] ?? "未命名"}");
      
      // Helper for simple fields
      void writeSimpleField(String key) {
        if (charData.containsKey(key) && charData[key] != null && charData[key].toString().isNotEmpty) {
           buffer.writeln("- **${keyTitleMap[key] ?? key}**: ${charData[key]}");
        }
      }

      void writeList(String title, String key) {
         if (charData[key] != null) {
            final list = charData[key] as List<dynamic>;
            if (list.isNotEmpty) {
               buffer.writeln("- **$title**: ${list.join(", ")}");
            }
         }
      }

      void writeCheckboxMap(String title, String key, Map<String, String> labels) {
         if (charData[key] != null) {
           final map = charData[key] as Map<String, dynamic>;
           final selected = <String>[];
           map.forEach((k, v) {
             if (v == true) {
               selected.add(labels[k] ?? k);
             }
           });
           if (selected.isNotEmpty) {
             buffer.writeln("- **$title**: ${selected.join(", ")}");
           }
         }
      }

      void writeSliders(String title, String key, List<TraitDefinition> defs) {
        if (charData[key] != null) {
          final values = charData[key] as List<dynamic>;
          if (values.isNotEmpty) {
            buffer.writeln("- **$title**:");
            for (int i = 0; i < values.length && i < defs.length; i++) {
              final def = defs[i];
              final rawVal = (values[i] as num).toDouble();
              
              String displayTitle = def.uiTitle;
              String displayValue = "";
              
              if (displayTitle.isNotEmpty) {
                 displayValue = rawVal.toStringAsFixed(1);
                 buffer.writeln("  - $displayTitle: $displayValue");
              } else {
                 if (rawVal < 50) {
                   displayTitle = def.uiLeft;
                   displayValue = (100 - rawVal).toStringAsFixed(1);
                 } else {
                   displayTitle = def.uiRight;
                   displayValue = rawVal.toStringAsFixed(1);
                 }
                 buffer.writeln("  - $displayTitle: $displayValue");
              }
            }
          }
        }
      }

      // --- Output Sections ---

      // Basic
      for (var key in ["name", "nickname", "age", "gender", "occupation", "birthday", "native", "live", "address"]) {
        writeSimpleField(key);
      }
      
      // Appearance
      buffer.writeln("\n### 外觀");
      for (var key in ["height", "weight", "blood", "hair", "eye", "skin", "faceFeatures", "eyeFeatures", "earFeatures", "noseFeatures", "mouthFeatures", "eyebrowFeatures", "body", "dress"]) {
        writeSimpleField(key);
      }

      // Story
      buffer.writeln("\n### 故事相關");
      writeSimpleField("intention");
      
      if (charData["hinderEvents"] != null) {
        final events = charData["hinderEvents"] as List<dynamic>;
        if (events.isNotEmpty) {
           buffer.writeln("- **阻礙事件**:");
           for (var e in events) {
             final event = e as Map<String, dynamic>;
             buffer.writeln("  - 事件: ${event["event"] ?? ""}, 解決: ${event["solve"] ?? ""}");
           }
        }
      }

      // Personality
      buffer.writeln("\n### 個性＆價值觀");
      for (var key in ["mbti", "personality", "language", "interest", "habit", "belief", "limit", "future", "cherish", "disgust", "fear", "curious", "expect", "alignment"]) {
        writeSimpleField(key);
      }
      writeSimpleField("otherValues");

      writeSliders("性格特質", "traitsValues", TraitDefinitions.traits);
      writeSliders("行事作風", "approachValues", TraitDefinitions.approaches);

      // Ability
      buffer.writeln("\n### 能力＆才華");
      writeList("熱愛做的事情", "loveToDoList");
      writeList("想要做還沒做的事情", "wantToDoList");
      writeList("討厭做的事情", "hateToDoList");
      writeList("害怕做的事情", "fearToDoList");
      writeList("擅長做的事情", "proficientToDoList");
      writeList("不擅長做的事情", "unProficientToDoList");
      
      writeSliders("生活常用技能", "commonAbilityValues", TraitDefinitions.commonAbilities);

      // Social
      buffer.writeln("\n### 社交相關");
      writeSimpleField("impression");
      writeSimpleField("likable");
      writeSimpleField("family");
      
      writeCheckboxMap("如何表達「喜歡」", "howToShowLove", howToShowLoveLabels);
      writeSimpleField("otherShowLove");

      writeCheckboxMap("如何表達好意", "howToShowGoodwill", howToShowGoodwillLabels);
      writeSimpleField("otherGoodwill");
      
      writeCheckboxMap("如何應對討厭的人", "handleHatePeople", handleHatePeopleLabels);
      writeSimpleField("otherHatePeople");

      writeSimpleField("relationship");
      writeSimpleField("isFindNewLove");
      writeSimpleField("isHarem");
      writeSimpleField("otherRelationship");
      
      writeSliders("社交相關項目", "socialItemValues", TraitDefinitions.socialItems);

      // Other
      buffer.writeln("\n### 其他");
      writeSimpleField("originalName");
      writeList("喜歡的人事物", "likeItemList");
      writeList("憧憬的人事物", "admireItemList");
      writeList("討厭的人事物", "hateItemList");
      writeList("害怕的人事物", "fearItemList");
      writeList("習慣的人事物", "familiarItemList");
      writeSimpleField("otherText");

      buffer.writeln("---");
      buffer.writeln();
    });
    return buffer.toString();
  }
}

// MARK: - 7. Interface (介面)
// 負責協調 IO、System、Parsing、Merging 四大模組

class FileService {
  static const String defaultFileName = "MonogatariProject";
  static const String projectExtension = ".mnproj"; // MonogatariAssistant 專案檔案
  static const String textExtension = ".txt";
  static const String markdownExtension = ".md";
  static const String projectVersion = "1.02"; // 專案結構版本

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
          uri: result.uri,
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
      // Android SAF URI Support
      if (Platform.isAndroid && projectFile.uri != null) {
        try {
          await _SystemBridge.writeToUri(projectFile.uri!, projectFile.content);
          return projectFile;
        } catch (e) {
          debugPrint("SAF Write failed (URI might be invalid or expired): $e");
          // Fallback to saveProjectAs if writing to URI fails
          return await saveProjectAs(projectFile);
        }
      }

      if (projectFile.filePath != null) {
        // 儲存到現有路徑
        try {
          await _FileIO.write(projectFile.filePath!, projectFile.content);
          return projectFile;
        } catch (e) {
          // 在移動設備上，如果直接寫入失敗（常見於外部存儲權限問題），則退回到另存新檔
          // 這樣可以確保檔案能被儲存，雖然會跳出對話框，但優於儲存失敗
          if (Platform.isAndroid || Platform.isIOS) {
            return await saveProjectAs(projectFile);
          }
          rethrow;
        }
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
        defaultName: "${projectFile.nameWithoutExtension}$projectExtension",
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
