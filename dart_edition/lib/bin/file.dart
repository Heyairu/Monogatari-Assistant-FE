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
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";
import "package:xml/xml.dart" as xml;

import "ui_library.dart";
import "../modules/baseinfoview.dart" as BaseInfoModule;
import "../modules/chapterselectionview.dart" as ChapterModule;
import "../modules/outlineview.dart" as OutlineModule;
import "../modules/planview.dart" as PlanModule;
import "../modules/worldsettingsview.dart";
import "../modules/characterview.dart";
import "../models/project_data.dart";
import "../models/project_file.dart";

export "../models/project_data.dart";
export "../models/project_file.dart";

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
  static const platform = MethodChannel(
    "com.heyairu.monogatari_assistant/file",
  );

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

  /// 保留 Android SAF 檔案的讀寫權限，讓後續自動儲存可直接寫回。
  static Future<void> persistUriPermission(String? uri) async {
    if (!Platform.isAndroid || uri == null || uri.trim().isEmpty) {
      return;
    }

    try {
      await platform.invokeMethod("persistUriPermission", {"uri": uri.trim()});
    } on PlatformException catch (e) {
      debugPrint("Persist Android URI permission failed: ${e.message}");
    }
  }

  /// 選擇 Android AutoBackup 目錄並保留 SAF 寫入權限。
  static Future<String?> selectAutoBackupDirectory() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      return await platform.invokeMethod<String>("selectAutoBackupDirectory");
    } on PlatformException catch (e) {
      throw FileException("選擇 AutoBackup 目錄失敗: ${e.message ?? e.code}");
    }
  }

  static Future<String?> getSelectedAutoBackupDirectory() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      return await platform.invokeMethod<String>(
        "getSelectedAutoBackupDirectory",
      );
    } on PlatformException catch (e) {
      debugPrint("Get selected Android backup directory failed: ${e.message}");
      return null;
    }
  }

  static Future<void> openSelectedAutoBackupDirectory() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await platform.invokeMethod("openSelectedAutoBackupDirectory");
    } on PlatformException catch (e) {
      throw FileException("開啟 AutoBackup 目錄失敗: ${e.message ?? e.code}");
    }
  }

  static Future<String> saveAutoBackupFile({
    required String fileName,
    required String content,
  }) async {
    if (!Platform.isAndroid) {
      throw FileException("此平台不支援 Android SAF 備份寫入");
    }

    try {
      final result = await platform.invokeMethod<String>("saveAutoBackupFile", {
        "fileName": fileName,
        "content": content,
      });
      if (result == null || result.trim().isEmpty) {
        throw FileException("Android SAF 未回傳備份檔案位置");
      }
      return result;
    } on PlatformException catch (e) {
      if (e.code == "NO_BACKUP_DIRECTORY") {
        throw FileException("請先在設定中選擇 AutoBackup 目錄。");
      }
      throw FileException("寫入 AutoBackup 失敗: ${e.message ?? e.code}");
    }
  }

  static Future<List<Map<String, Object?>>> listAutoBackupFiles() async {
    if (!Platform.isAndroid) return const [];
    final result = await platform.invokeListMethod<dynamic>(
      "listAutoBackupFiles",
    );
    return (result ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (entry) => entry.map(
            (key, value) => MapEntry(key.toString(), value as Object?),
          ),
        )
        .toList(growable: false);
  }

  static Future<void> deleteAutoBackupFile(String uri) async {
    if (!Platform.isAndroid) return;
    await platform.invokeMethod<void>("deleteAutoBackupFile", {"uri": uri});
  }

  static Future<int?> getAvailableBackupBytes() async {
    if (!Platform.isAndroid) return null;
    return platform.invokeMethod<int>("getAvailableBackupBytes");
  }

  /// 建立 macOS security-scoped bookmark
  static Future<String?> createSecurityScopedBookmark(String filePath) async {
    if (!Platform.isMacOS || filePath.trim().isEmpty) {
      return null;
    }

    try {
      return await platform.invokeMethod<String>(
        "createSecurityScopedBookmark",
        {"path": filePath},
      );
    } on PlatformException catch (e) {
      debugPrint("Create macOS bookmark failed: ${e.message}");
      return null;
    }
  }

  /// 透過 macOS security-scoped bookmark 開啟檔案
  static Future<({String name, String? path, String? uri, String content})?>
  openProjectFromSecurityScopedBookmark(String bookmark) async {
    if (!Platform.isMacOS || bookmark.trim().isEmpty) {
      return null;
    }

    try {
      final dynamic rawResult = await platform.invokeMethod<dynamic>(
        "openProjectFromSecurityScopedBookmark",
        {"bookmark": bookmark},
      );

      if (rawResult is! Map) {
        return null;
      }

      final rawName = rawResult["name"];
      final rawPath = rawResult["path"];
      final rawUri = rawResult["uri"];
      final rawContent = rawResult["content"];

      if (rawName is! String ||
          rawName.trim().isEmpty ||
          rawContent is! String) {
        return null;
      }

      return (
        name: rawName,
        path: rawPath is String && rawPath.trim().isNotEmpty
            ? rawPath.trim()
            : null,
        uri: rawUri is String && rawUri.trim().isNotEmpty
            ? rawUri.trim()
            : bookmark,
        content: rawContent,
      );
    } on PlatformException catch (e) {
      throw FileException("無法以持久授權開啟檔案: ${e.message ?? e.code}");
    }
  }

  /// 選擇專案檔案並讀取內容 (因為 FilePicker 在某些平台直接給 bytes)
  static Future<({String name, String? path, String? uri, String content})?>
  pickProjectFile() async {
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

    if (result == null) {
      return null;
    }

    final file = result.files.single;
    final filePath = file.path?.trim();

    String? content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!);
    } else if (filePath != null && filePath.isNotEmpty) {
      content = await _FileIO.read(filePath);
    }

    if (content == null) {
      return null;
    }

    return (
      name: file.name,
      path: filePath,
      uri: file.identifier,
      content: content,
    );
  }

  /// 顯示儲存專案對話框
  static Future<String?> saveProjectFileDialog({
    required String defaultName,
    required String content,
  }) async {
    if (Platform.isAndroid) {
      return await FilePicker.platform.saveFile(
        dialogTitle: "儲存專案檔案",
        fileName: defaultName,
        type: FileType.any,
        bytes: utf8.encode(content),
      );
    } else if (Platform.isIOS) {
      return await FilePicker.platform.saveFile(
        dialogTitle: "儲存專案檔案",
        fileName: defaultName,
        type: FileType.any,
        bytes: utf8.encode(content),
      );
    } else {
      // macOS, Windows, Linux: 不傳遞 bytes，由應用程式寫入檔案
      return await FilePicker.platform.saveFile(
        dialogTitle: "儲存專案檔案",
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ["mnproj"],
      );
    }
  }

  /// 顯示匯出對話框
  static Future<String?> saveExportDialog({
    required String defaultName,
    required String extension,
    required String content,
  }) async {
    // 僅在 Android 和 iOS 上傳遞 bytes
    // macOS, Windows, Linux: 由應用程式寫入檔案
    if (Platform.isAndroid || Platform.isIOS) {
      return await FilePicker.platform.saveFile(
        dialogTitle: "匯出文字檔案",
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: [extension.substring(1)], // 移除點號
        bytes: utf8.encode(content),
      );
    } else {
      return await FilePicker.platform.saveFile(
        dialogTitle: "匯出文字檔案",
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: [extension.substring(1)], // 移除點號
      );
    }
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
  static bool hasUnsavedChanges(bool hasUnsavedChanges) {
    return hasUnsavedChanges;
  }

  static ({int segIndex, int chapIndex})? _findSelectedChapter({
    required List<ChapterModule.SegmentData> segmentsData,
    required String? selectedSegID,
    required String? selectedChapID,
  }) {
    if (selectedSegID == null || selectedChapID == null) return null;

    final segIndex = segmentsData.indexWhere(
      (seg) => seg.segmentUUID == selectedSegID,
    );
    if (segIndex < 0) return null;

    final chapIndex = segmentsData[segIndex].chapters.indexWhere(
      (chap) => chap.chapterUUID == selectedChapID,
    );
    if (chapIndex < 0) return null;

    return (segIndex: segIndex, chapIndex: chapIndex);
  }

  static bool hasEditorContentChangedForSelectedChapter({
    required List<ChapterModule.SegmentData> segmentsData,
    required String? selectedSegID,
    required String? selectedChapID,
    required TextEditingController textController,
  }) {
    final selectedChapter = _findSelectedChapter(
      segmentsData: segmentsData,
      selectedSegID: selectedSegID,
      selectedChapID: selectedChapID,
    );
    if (selectedChapter == null) return false;

    final currentChapter = segmentsData[selectedChapter.segIndex]
        .chapters[selectedChapter.chapIndex];
    return currentChapter.chapterContent != textController.text;
  }

  /// 同步編輯器內容到選中的章節
  static bool syncEditorToSelectedChapter({
    required List<ChapterModule.SegmentData> segmentsData,
    required String? selectedSegID,
    required String? selectedChapID,
    required TextEditingController textController,
    required Function(String) updateContentCallback,
  }) {
    // 防呆檢查
    final selectedChapter = _findSelectedChapter(
      segmentsData: segmentsData,
      selectedSegID: selectedSegID,
      selectedChapID: selectedChapID,
    );
    if (selectedChapter == null) return false;

    final segment = segmentsData[selectedChapter.segIndex];
    final currentEditorContent = textController.text;
    final currentChapter = segment.chapters[selectedChapter.chapIndex];
    if (currentChapter.chapterContent == currentEditorContent) {
      return false;
    }

    final chapters = [...segment.chapters];
    chapters[selectedChapter.chapIndex] = currentChapter.copyWith(
      chapterContent: currentEditorContent,
    );
    segmentsData[selectedChapter.segIndex] = segment.copyWith(
      chapters: chapters,
    );
    updateContentCallback(currentEditorContent);
    return true;
  }

  /// 生成專案XML內容
  static Future<String> generateProjectXML(
    ProjectData data, {
    bool updateLatestSave = true,
  }) async {
    if (updateLatestSave) {
      return compute(FileService.generateProjectXML, data);
    }
    return compute(FileService.generateProjectXMLWithoutLatestSaveUpdate, data);
  }

  /// 從XML載入專案
  static Future<ProjectData> loadProjectFromXML(ProjectFile projectFile) async {
    final result = await loadProjectParseResultFromXML(projectFile);
    return result.data;
  }

  /// 從XML載入專案，並回傳同一次解析取得的檔案版本
  static Future<ProjectParseResult> loadProjectParseResultFromXML(
    ProjectFile projectFile,
  ) async {
    try {
      final content = projectFile.takeContent();
      return compute(FileService.parseProjectXMLWithMetadata, content);
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

    return AppDialog.showCustom<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              title: title,
              icon: Icons.warning_amber_rounded,
              tone: AppFeedbackTone.error,
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

  /// 顯示版本相容性警告對話框
  static Future<bool> showVersionCompatibilityDialog(
    BuildContext context, {
    required String fileVersion,
    required String supportedVersion,
  }) async {
    final result = await AppDialog.showCustom<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AppDialog(
          title: "版本相容性警告",
          icon: Icons.warning_amber_rounded,
          tone: AppFeedbackTone.error,
          content: Text(
            "此檔案版本（$fileVersion）高於目前支援版本（$supportedVersion）。\n"
            "若繼續開啟並儲存，可能遺失部分數據。\n\n"
            "是否仍要繼續開啟？",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text("取消"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text("繼續開啟"),
            ),
          ],
        );
      },
    );

    return result ?? false;
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
        final parseResult = await loadProjectParseResultFromXML(projectFile);
        final openedVersion = parseResult.projectVersion;
        final hasNewerVersion = FileService.isProjectVersionNewerThanSupported(
          openedVersion,
        );

        if (hasNewerVersion) {
          setLoading(false);
          if (!context.mounted) return;

          final shouldContinue = await showVersionCompatibilityDialog(
            context,
            fileVersion: openedVersion ?? "unknown",
            supportedVersion: FileService.projectVersion,
          );

          if (!shouldContinue) {
            onError("已取消開啟較新版本檔案。");
            return;
          }
          setLoading(true);
        }

        final data = parseResult.data;
        onProjectLoaded(projectFile, data);
        onSuccess("專案開啟成功：${projectFile.nameWithoutExtension}");
      }
    } catch (e) {
      onError("開啟專案失敗：${e.toString()}");
    } finally {
      setLoading(false);
    }
  }

  static Future<void> openProjectFromPath(
    BuildContext context, {
    required String filePath,
    String? accessToken,
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
        title: "開啟最近專案",
        message: "您有未儲存的變更，是否要在開啟最近專案前儲存？",
        onDontShowAgainChanged: (_) {},
        onSave: onSave,
      );
      if (shouldProceed == null) return;
    }

    try {
      setLoading(true);
      final projectFile = await FileService.openProjectFromPath(
        filePath,
        accessToken: accessToken,
      );
      final parseResult = await loadProjectParseResultFromXML(projectFile);
      final openedVersion = parseResult.projectVersion;
      final hasNewerVersion = FileService.isProjectVersionNewerThanSupported(
        openedVersion,
      );

      if (hasNewerVersion) {
        setLoading(false);
        if (!context.mounted) return;

        final shouldContinue = await showVersionCompatibilityDialog(
          context,
          fileVersion: openedVersion ?? "unknown",
          supportedVersion: FileService.projectVersion,
        );

        if (!shouldContinue) {
          onError("已取消開啟較新版本檔案。");
          return;
        }
        setLoading(true);
      }

      final data = parseResult.data;
      onProjectLoaded(projectFile, data);
      onSuccess("專案開啟成功：${projectFile.nameWithoutExtension}");
    } catch (e) {
      onError("開啟最近專案失敗：${e.toString()}");
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
          onProjectSaved: onProjectSaved,
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

      final projectToSave =
          currentProject ?? await FileService.createNewProject();

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
          final xml = ChapterModule.ChapterSelectionCodec.saveXML(
            currentData.segmentsData,
          );
          if (xml != null) buffer.writeln(xml);
        }

        if (selectedModules.contains("Outline")) {
          final xml = OutlineModule.OutlineCodec.saveXML(
            currentData.outlineData,
          );
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
          buffer.writeln(
            _ProjectMerger.generateBaseInfoMD(
              currentData.baseInfoData,
              currentData.totalWords,
            ),
          );
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("Chapters")) {
          buffer.writeln(
            _ProjectMerger.generateChapterMD(currentData.segmentsData),
          );
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("Outline")) {
          buffer.writeln(
            _ProjectMerger.generateOutlineMD(currentData.outlineData),
          );
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("WorldSettings")) {
          buffer.writeln(
            _ProjectMerger.generateWorldSettingsMD(
              currentData.worldSettingsData,
            ),
          );
          buffer.writeln("---");
          buffer.writeln();
        }

        if (selectedModules.contains("Characters")) {
          buffer.writeln(
            _ProjectMerger.generateCharacterMD(currentData.characterData),
          );
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

class _AutoBackupFileEntry {
  final String name;
  final String location;
  final int size;
  final DateTime modified;

  const _AutoBackupFileEntry({
    required this.name,
    required this.location,
    required this.size,
    required this.modified,
  });
}

// MARK: - 5. Parsing (解析)
/// 負責將 XML 字串解析為資料結構
class _ProjectParser {
  static ProjectParseResult parseProjectXMLWithMetadata(String xmlContent) {
    // 準備載入的數據 - 使用 ProjectData.empty() 作為預設值
    final defaultData = ProjectData.empty();
    String? projectVersion;

    BaseInfoModule.BaseInfoData? loadedBaseInfo;
    List<ChapterModule.SegmentData>? loadedSegments;
    List<OutlineModule.StorylineData>? loadedOutline;
    List<PlanModule.ForeshadowItem>? loadedForeshadow;
    List<PlanModule.UpdatePlanItem>? loadedUpdatePlans;
    List<LocationData>? loadedWorldSettings;
    Map<String, CharacterEntryData>? loadedCharacterData;

    // 計算 contentText 和 totalWords
    String contentText = "";
    int totalWords = 0;

    try {
      final document = xml.XmlDocument.parse(xmlContent);
      final version = document
          .findAllElements("ver")
          .firstOrNull
          ?.innerText
          .trim();
      if (version != null && version.isNotEmpty) {
        projectVersion = version;
      }

      // 尋找所有的 Type 區塊
      final typeElements = document.findAllElements("Type");

      for (final element in typeElements) {
        // 檢查 Name 標籤確認區塊類型
        final nameElement = element.findElements("Name").firstOrNull;
        if (nameElement == null) continue;

        final typeName = nameElement.innerText;

        try {
          switch (typeName) {
            case "BaseInfo":
              // 避免重複載入，只取第一個遇到的有效區塊
              loadedBaseInfo ??= BaseInfoModule.BaseInfoCodec.loadElement(
                element,
              );
              break;

            case "ChapterSelection":
              loadedSegments ??=
                  ChapterModule.ChapterSelectionCodec.loadElement(element);
              break;

            case "Outline":
              loadedOutline ??= OutlineModule.OutlineCodec.loadElement(element);
              break;

            case "PlanSettings":
              final planData = PlanModule.PlanCodec.loadElement(element);
              if (planData != null) {
                loadedForeshadow ??= planData.foreshadows;
                loadedUpdatePlans ??= planData.updatePlans;
              }
              break;

            case "WorldSettings":
              loadedWorldSettings ??= WorldSettingsCodec.loadElement(element);
              break;

            case "Characters":
              loadedCharacterData ??= CharacterCodec.loadElement(element);
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

    List<ChapterModule.SegmentData> snapshotSegments(
      List<ChapterModule.SegmentData> source,
    ) {
      return List<ChapterModule.SegmentData>.unmodifiable(
        source
            .map(
              (segment) => segment.copyWith(
                chapters: segment.chapters
                    .map((chapter) => chapter.copyWith())
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
      );
    }

    List<OutlineModule.StorylineData> snapshotOutline(
      List<OutlineModule.StorylineData> source,
    ) {
      return List<OutlineModule.StorylineData>.unmodifiable(
        source
            .map(
              (storyline) => storyline.copyWith(
                people: [...storyline.people],
                item: [...storyline.item],
                scenes: storyline.scenes
                    .map(
                      (event) => event.copyWith(
                        people: [...event.people],
                        item: [...event.item],
                        scenes: event.scenes
                            .map(
                              (scene) => scene.copyWith(
                                people: [...scene.people],
                                item: [...scene.item],
                                doingThings: [...scene.doingThings],
                              ),
                            )
                            .toList(growable: false),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
      );
    }

    final parsedBaseInfo = (loadedBaseInfo ?? defaultData.baseInfoData)
        .copyWith(tags: [...(loadedBaseInfo ?? defaultData.baseInfoData).tags]);
    final parsedSegments = snapshotSegments(
      loadedSegments ?? defaultData.segmentsData,
    );
    final parsedOutline = snapshotOutline(
      loadedOutline ?? defaultData.outlineData,
    );

    // 如果有載入章節數據，使用第一個章節的內容
    final targetSegments = parsedSegments;
    if (targetSegments.isNotEmpty && targetSegments[0].chapters.isNotEmpty) {
      contentText = targetSegments[0].chapters[0].chapterContent;
      // 簡單的字數統計
      totalWords = contentText
          .split(RegExp(r"\s+"))
          .where((word) => word.isNotEmpty)
          .length;
    }

    return ProjectParseResult(
      projectVersion: projectVersion,
      data: ProjectData(
        baseInfoData: parsedBaseInfo,
        segmentsData: parsedSegments,
        outlineData: parsedOutline,
        foreshadowData: loadedForeshadow ?? defaultData.foreshadowData,
        updatePlanData: loadedUpdatePlans ?? defaultData.updatePlanData,
        worldSettingsData: loadedWorldSettings ?? defaultData.worldSettingsData,
        characterData: loadedCharacterData ?? defaultData.characterData,
        totalWords: totalWords,
        contentText: contentText,
      ),
    );
  }

  static ProjectData parseProjectXML(String xmlContent) {
    return parseProjectXMLWithMetadata(xmlContent).data;
  }
}

// MARK: - 6. Merging (合併)
/// 負責將資料結構合併/生成為 XML 或其他格式
class _ProjectMerger {
  /// 生成專案XML內容
  static String generateProjectXML(
    ProjectData data, {
    bool updateLatestSave = true,
  }) {
    final buffer = StringBuffer();

    buffer.writeln("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
    buffer.writeln("<Project>");
    buffer.writeln("<ver>${FileService.projectVersion}</ver>");

    // BaseInfo
    final baseInfoXml = BaseInfoModule.BaseInfoCodec.saveXML(
      data: data.baseInfoData,
      totalWords: data.totalWords,
      contentText: data.contentText,
      updateLatestSave: updateLatestSave,
    );
    if (baseInfoXml != null) {
      buffer.writeln(baseInfoXml);
    }

    // ChapterSelection
    final chapterXml = ChapterModule.ChapterSelectionCodec.saveXML(
      data.segmentsData,
    );
    if (chapterXml != null) {
      buffer.writeln(chapterXml);
    }

    // Outline
    final outlineXml = OutlineModule.OutlineCodec.saveXML(data.outlineData);
    if (outlineXml != null) {
      buffer.writeln(outlineXml);
    }

    // PlanSettings
    final planXml = PlanModule.PlanCodec.saveXML(
      data.foreshadowData,
      data.updatePlanData,
    );
    if (planXml != null) {
      buffer.writeln();
      buffer.write(planXml);
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
  static String generateBaseInfoMD(
    BaseInfoModule.BaseInfoData data,
    int totalWords,
  ) {
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
  static String generateOutlineMD(
    List<OutlineModule.StorylineData> storylines,
  ) {
    final buffer = StringBuffer();
    buffer.writeln("# 大綱 (Outline)");
    buffer.writeln();
    for (final storyline in storylines) {
      buffer.writeln(
        "## ${storyline.storylineName} (${storyline.storylineType})",
      );
      if (storyline.memo.isNotEmpty) buffer.writeln("備註: ${storyline.memo}");
      if (storyline.conflictPoint.isNotEmpty)
        buffer.writeln("衝突點: ${storyline.conflictPoint}");
      if (storyline.people.isNotEmpty)
        buffer.writeln("人物: ${storyline.people.join(", ")}");
      if (storyline.item.isNotEmpty)
        buffer.writeln("物件: ${storyline.item.join(", ")}");

      buffer.writeln("### 場景列表:");
      for (final event in storyline.scenes) {
        buffer.writeln("- **${event.storyEvent}**");
        if (event.memo.isNotEmpty) buffer.writeln("  - 備註: ${event.memo}");
        if (event.conflictPoint.isNotEmpty)
          buffer.writeln("  - 衝突: ${event.conflictPoint}");
        if (event.people.isNotEmpty)
          buffer.writeln("  - 人物: ${event.people.join(", ")}");
        if (event.item.isNotEmpty)
          buffer.writeln("  - 物件: ${event.item.join(", ")}");

        for (final scene in event.scenes) {
          buffer.writeln("  - [場景] ${scene.sceneName}");
          if (scene.doingThings.isNotEmpty)
            buffer.writeln("    - 行動: ${scene.doingThings.join(", ")}");
          if (scene.people.isNotEmpty)
            buffer.writeln("    - 人物: ${scene.people.join(", ")}");
          if (scene.item.isNotEmpty)
            buffer.writeln("    - 物件: ${scene.item.join(", ")}");
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
  static String generateCharacterMD(
    Map<String, CharacterEntryData> characters,
  ) {
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

    characters.forEach((id, entryData) {
      final charData = entryData.toLegacyMap();
      buffer.writeln("## ${charData["name"] ?? "未命名"}");

      // Helper for simple fields
      void writeSimpleField(String key) {
        if (charData.containsKey(key) &&
            charData[key] != null &&
            charData[key].toString().isNotEmpty) {
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

      void writeCheckboxMap(
        String title,
        String key,
        Map<String, String> labels,
      ) {
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
      for (var key in [
        "name",
        "nickname",
        "age",
        "gender",
        "occupation",
        "birthday",
        "native",
        "live",
        "address",
      ]) {
        writeSimpleField(key);
      }

      // Appearance
      buffer.writeln("\n### 外觀");
      for (var key in [
        "height",
        "weight",
        "blood",
        "hair",
        "eye",
        "skin",
        "faceFeatures",
        "eyeFeatures",
        "earFeatures",
        "noseFeatures",
        "mouthFeatures",
        "eyebrowFeatures",
        "body",
        "dress",
      ]) {
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
            buffer.writeln(
              "  - 事件: ${event["event"] ?? ""}, 解決: ${event["solve"] ?? ""}",
            );
          }
        }
      }

      // Personality
      buffer.writeln("\n### 個性＆價值觀");
      for (var key in [
        "mbti",
        "personality",
        "language",
        "interest",
        "habit",
        "belief",
        "limit",
        "future",
        "cherish",
        "disgust",
        "fear",
        "curious",
        "expect",
        "alignment",
      ]) {
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

      writeSliders(
        "生活常用技能",
        "commonAbilityValues",
        TraitDefinitions.commonAbilities,
      );

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
  static const String defaultFileName = "Untitled";
  static const String projectExtension = ".mnproj"; // MonogatariAssistant 專案檔案
  static const String textExtension = ".txt";
  static const String markdownExtension = ".md";
  static const String projectVersion = "1.06"; // 專案結構版本
  static const String autoBackupFolderNameDesktop = "autosave";
  static const String autoBackupFolderNameMobile = "MonoAshi_Backup";
  static const String _customAutoBackupDirectoryKey =
      "custom_auto_backup_directory";

  /// 從專案 XML 取出版本號（`<ver>`）
  static String? extractProjectVersion(String xmlContent) {
    try {
      final document = xml.XmlDocument.parse(xmlContent);
      final versionElement = document.findAllElements("ver").firstOrNull;
      final version = versionElement?.innerText.trim();
      if (version == null || version.isEmpty) return null;
      return version;
    } catch (_) {
      return null;
    }
  }

  /// 判斷檔案版本是否高於目前支援版本
  static bool isProjectVersionNewerThanSupported(String? fileVersion) {
    if (fileVersion == null || fileVersion.isEmpty) return false;
    return _compareVersion(fileVersion, projectVersion) > 0;
  }

  /// 比較語義版本字串，a > b 回傳 1，a < b 回傳 -1，相等回傳 0
  static int _compareVersion(String a, String b) {
    final aParts = a.split(".").map((p) => int.tryParse(p) ?? 0).toList();
    final bParts = b.split(".").map((p) => int.tryParse(p) ?? 0).toList();
    final maxLength = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;

    for (var i = 0; i < maxLength; i++) {
      final aValue = i < aParts.length ? aParts[i] : 0;
      final bValue = i < bParts.length ? bParts[i] : 0;
      if (aValue > bValue) return 1;
      if (aValue < bValue) return -1;
    }
    return 0;
  }

  static bool _isPermissionDeniedError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains("permission denied") ||
        message.contains("operation not permitted") ||
        message.contains("access denied") ||
        message.contains("errno = 13");
  }

  static bool _looksLikeLocalPath(String value) {
    return value.startsWith("/") ||
        value.startsWith("\\") ||
        RegExp(r"^[a-zA-Z]:[\\/]").hasMatch(value);
  }

  static String? _normalizeLocalPathOrNull(String? rawPath) {
    if (rawPath == null) {
      return null;
    }

    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme.toLowerCase() == "file") {
      try {
        return uri.toFilePath(windows: Platform.isWindows);
      } catch (_) {
        return null;
      }
    }

    if (_looksLikeLocalPath(trimmed)) {
      return trimmed;
    }

    return null;
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, "0");

  static String _formatBackupTimestamp(DateTime now) {
    final yy = _twoDigits(now.year % 100);
    final mm = _twoDigits(now.month);
    final dd = _twoDigits(now.day);
    final hh = _twoDigits(now.hour);
    final min = _twoDigits(now.minute);
    final ss = _twoDigits(now.second);
    final millis = now.millisecond.toString().padLeft(3, "0");
    return "${yy}${mm}${dd}_${hh}${min}${ss}_$millis";
  }

  static String _sanitizeBackupProjectName(String projectName) {
    final sanitized = projectName
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), "_")
        .replaceAll(RegExp(r"\s+"), " ")
        .replaceAll(RegExp(r"^\.+|\.+$"), "");
    return sanitized.isEmpty ? defaultFileName : sanitized;
  }

  static Future<Directory> _defaultAutoBackupDirectory() async {
    if (Platform.isWindows) {
      final appData = Platform.environment["APPDATA"];
      if (appData != null && appData.trim().isNotEmpty) {
        return Directory(
          path.join(appData, "MonogatariAsstant", autoBackupFolderNameDesktop),
        );
      }
    }

    if (Platform.isMacOS) {
      final home = Platform.environment["HOME"];
      if (home != null && home.trim().isNotEmpty) {
        return Directory(
          path.join(
            home,
            "Library",
            "Containers",
            "com.heyairu.monoashi",
            autoBackupFolderNameDesktop,
          ),
        );
      }
    }

    if (Platform.isLinux) {
      final home = Platform.environment["HOME"];
      if (home != null && home.trim().isNotEmpty) {
        return Directory(
          path.join(
            home,
            ".config",
            "MonogatariAsstant",
            autoBackupFolderNameDesktop,
          ),
        );
      }
    }

    final supportDir = await getApplicationSupportDirectory();
    return Directory(path.join(supportDir.path, autoBackupFolderNameMobile));
  }

  static Future<String?> _customAutoBackupDirectoryPath() async {
    if (Platform.isAndroid) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_customAutoBackupDirectoryKey)?.trim();
    return savedPath == null || savedPath.isEmpty ? null : savedPath;
  }

  static Future<void> _setCustomAutoBackupDirectoryPath(
    String? directoryPath,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = directoryPath?.trim();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_customAutoBackupDirectoryKey);
      return;
    }

    final defaultDir = await _defaultAutoBackupDirectory();
    if (path.equals(
      path.normalize(normalized),
      path.normalize(defaultDir.path),
    )) {
      await prefs.remove(_customAutoBackupDirectoryKey);
      return;
    }

    await prefs.setString(_customAutoBackupDirectoryKey, normalized);
  }

  static Future<Directory> _autoBackupDirectory() async {
    final customPath = await _customAutoBackupDirectoryPath();
    if (customPath != null) {
      return Directory(customPath);
    }
    return _defaultAutoBackupDirectory();
  }

  static Future<Directory> _ensureAutoBackupDirectory() async {
    final backupDir = await _autoBackupDirectory();
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// 建立平台持久化存取 token（目前 macOS 會回傳 security-scoped bookmark）
  static Future<String?> createPersistentAccessToken(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) {
      return null;
    }
    if (!Platform.isMacOS) {
      return null;
    }
    final normalizedPath = _normalizeLocalPathOrNull(filePath);
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return null;
    }
    return await _SystemBridge.createSecurityScopedBookmark(normalizedPath);
  }

  // --- 專案生命週期 ---

  /// 創建新專案
  static Future<ProjectFile> createNewProject() async {
    return ProjectFile(fileName: defaultFileName, filePath: null, content: "");
  }

  /// 開啟專案檔案
  static Future<ProjectFile?> openProject() async {
    try {
      final result = await _SystemBridge.pickProjectFile();
      if (result != null) {
        final normalizedPath =
            _normalizeLocalPathOrNull(result.path) ??
            _normalizeLocalPathOrNull(result.uri);
        final resolvedFileName = result.name.trim().isNotEmpty
            ? result.name.trim()
            : (normalizedPath != null
                  ? path.basename(normalizedPath)
                  : "$defaultFileName$projectExtension");
        await _SystemBridge.persistUriPermission(result.uri);
        return ProjectFile(
          fileName: resolvedFileName,
          filePath: normalizedPath,
          uri: result.uri,
          content: result.content,
        );
      }
    } catch (e) {
      throw FileException("開啟檔案失敗: ${e.toString()}");
    }
    return null;
  }

  /// 依照完整路徑開啟專案檔案
  static Future<ProjectFile> openProjectFromPath(
    String filePath, {
    String? accessToken,
  }) async {
    final normalizedPath =
        _normalizeLocalPathOrNull(filePath) ?? filePath.trim();
    if (normalizedPath.isEmpty) {
      throw FileException("檔案路徑不可為空");
    }

    try {
      final exists = await _FileIO.exists(normalizedPath);
      if (!exists) {
        throw FileException("檔案不存在：$normalizedPath");
      }

      final content = await _FileIO.read(normalizedPath);
      return ProjectFile(
        fileName: path.basename(normalizedPath),
        filePath: normalizedPath,
        content: content,
      );
    } catch (e) {
      if (e is FileException) {
        rethrow;
      }

      final normalizedToken = accessToken?.trim();

      // On macOS, reopening a path from Recent may fail if file permission
      // tokens expire; try bookmark-based access first, then re-authorize.
      if (Platform.isMacOS && _isPermissionDeniedError(e)) {
        if (normalizedToken != null && normalizedToken.isNotEmpty) {
          try {
            final reopened =
                await _SystemBridge.openProjectFromSecurityScopedBookmark(
                  normalizedToken,
                );
            if (reopened != null) {
              return ProjectFile(
                fileName: reopened.name,
                filePath: reopened.path ?? normalizedPath,
                uri: reopened.uri,
                content: reopened.content,
              );
            }
          } catch (_) {
            // Fall through to picker-based re-authorization.
          }
        }

        final picked = await _SystemBridge.pickProjectFile();
        if (picked != null) {
          return ProjectFile(
            fileName: picked.name,
            filePath: picked.path,
            uri: picked.uri,
            content: picked.content,
          );
        }
        throw FileException("最近檔案權限已失效，請重新選取檔案。");
      }

      throw FileException("開啟最近檔案失敗: ${e.toString()}");
    }
  }

  /// 儲存專案檔案
  static Future<ProjectFile> saveProject(ProjectFile projectFile) async {
    try {
      // Android SAF URI Support
      if (Platform.isAndroid && projectFile.uri != null) {
        try {
          await _SystemBridge.writeToUri(projectFile.uri!, projectFile.content);
          projectFile.content = "";
          return projectFile;
        } catch (e) {
          debugPrint("SAF Write failed (URI might be invalid or expired): $e");
          // Fallback to saveProjectAs if writing to URI fails
          return await saveProjectAs(projectFile);
        }
      }

      final normalizedPath = _normalizeLocalPathOrNull(projectFile.filePath);

      if (normalizedPath != null) {
        projectFile.filePath = normalizedPath;
        // 儲存到現有路徑
        try {
          await _FileIO.write(normalizedPath, projectFile.content);
          projectFile.content = "";
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
      projectFile.content = "";
      throw FileException("儲存檔案失敗: ${e.toString()}");
    }
  }

  /// 只儲存到已知位置，不觸發另存新檔對話框。
  static Future<ProjectFile> saveProjectToKnownLocation(
    ProjectFile projectFile,
  ) async {
    try {
      if (Platform.isAndroid && projectFile.uri != null) {
        await _SystemBridge.writeToUri(projectFile.uri!, projectFile.content);
        projectFile.content = "";
        return projectFile;
      }

      final normalizedPath = _normalizeLocalPathOrNull(projectFile.filePath);
      if (normalizedPath == null) {
        throw FileException("自動儲存需要已知檔案路徑。");
      }

      projectFile.filePath = normalizedPath;
      await _FileIO.write(normalizedPath, projectFile.content);
      projectFile.content = "";
      return projectFile;
    } catch (e) {
      projectFile.content = "";
      if (e is FileException) {
        rethrow;
      }
      throw FileException("自動儲存失敗: ${e.toString()}");
    }
  }

  /// 另存新檔
  static Future<ProjectFile> saveProjectAs(ProjectFile projectFile) async {
    try {
      final content = projectFile.takeContent();
      final outputFileRaw = await _SystemBridge.saveProjectFileDialog(
        defaultName: "${projectFile.nameWithoutExtension}$projectExtension",
        content: content,
      );

      // 如果使用者取消儲存
      if (outputFileRaw == null) {
        throw FileException("另存檔案已取消");
      }

      final outputFile = outputFileRaw.trim();
      if (outputFile.isEmpty) {
        throw FileException("另存檔案失敗: 無效檔案路徑");
      }

      final normalizedPath =
          _normalizeLocalPathOrNull(outputFile) ?? outputFile;
      final normalizedLocalPath = _normalizeLocalPathOrNull(normalizedPath);
      final outputUri = normalizedLocalPath == null ? normalizedPath : null;
      await _SystemBridge.persistUriPermission(outputUri);

      // 在桌面平台上仍需要寫入檔案 (SystemBridge 可能只回傳路徑)
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await _FileIO.write(normalizedPath, content);
      }

      final resolvedFileName = _looksLikeLocalPath(normalizedPath)
          ? path.basenameWithoutExtension(normalizedPath)
          : (projectFile.fileName.trim().isNotEmpty
                ? projectFile.fileName.trim()
                : defaultFileName);

      return ProjectFile(
        fileName: resolvedFileName,
        filePath: normalizedLocalPath,
        uri: outputUri,
        content: "",
      );
    } catch (e) {
      throw FileException("另存檔案失敗: ${e.toString()}");
    }
  }

  /// 寫入 AutoBackup 檔案，不影響目前專案路徑或未儲存狀態。
  static Future<String> saveProjectAutoBackup({
    required String projectName,
    required String content,
    required int maxTotalBytes,
  }) async {
    try {
      final safeProjectName = _sanitizeBackupProjectName(projectName);
      final timestamp = _formatBackupTimestamp(DateTime.now());
      final backupName =
          "${safeProjectName}_backup_$timestamp$projectExtension";

      final contentBytes = utf8.encode(content).length;
      if (contentBytes > maxTotalBytes) {
        throw FileException("單一專案備份已超過設定的 AutoBackup 容量上限，請提高上限。");
      }
      final availableBytes = await _availableBackupBytes();
      if (availableBytes != null &&
          availableBytes < contentBytes + (16 * 1024 * 1024)) {
        throw FileException("AutoBackup 可用空間不足，請清理備份或更換目錄。");
      }

      late final String savedLocation;
      if (Platform.isAndroid) {
        savedLocation = await _SystemBridge.saveAutoBackupFile(
          fileName: backupName,
          content: content,
        );
      } else {
        final backupDir = await _ensureAutoBackupDirectory();
        final backupPath = path.join(backupDir.path, backupName);
        final temporaryPath = "$backupPath.tmp";
        await _FileIO.write(temporaryPath, content);
        await File(temporaryPath).rename(backupPath);
        savedLocation = backupPath;
      }

      try {
        await _pruneAutoBackups(
          projectName: safeProjectName,
          maxTotalBytes: maxTotalBytes,
          maxGenerations: 100,
          maxAge: const Duration(days: 30),
        );
      } catch (error, stackTrace) {
        debugPrint("AutoBackup cleanup failed: $error\n$stackTrace");
      }
      return savedLocation;
    } catch (e) {
      throw FileException("寫入 AutoBackup 失敗: ${e.toString()}");
    }
  }

  /// 取得 AutoBackup 目錄；若尚未存在會先建立。
  static Future<String> getAutoBackupDirectoryPath() async {
    final info = await getAutoBackupDirectoryInfo();
    return info.path;
  }

  static Future<AutoBackupDirectoryInfo> getAutoBackupDirectoryInfo() async {
    final inventory = await _listAutoBackupFiles();
    final totalBytes = inventory.fold<int>(0, (sum, item) => sum + item.size);
    if (Platform.isAndroid) {
      final selectedUri = await _SystemBridge.getSelectedAutoBackupDirectory();
      return AutoBackupDirectoryInfo(
        path: selectedUri ?? "",
        isConfigured: selectedUri != null && selectedUri.trim().isNotEmpty,
        isDefault: false,
        canReset: false,
        isAndroid: true,
        totalBytes: totalBytes,
        fileCount: inventory.length,
      );
    }

    final defaultDir = await _defaultAutoBackupDirectory();
    final customPath = await _customAutoBackupDirectoryPath();
    final activePath = customPath ?? defaultDir.path;
    final isDefault = customPath == null;

    return AutoBackupDirectoryInfo(
      path: activePath,
      isConfigured: true,
      isDefault: isDefault,
      canReset: !isDefault,
      isAndroid: false,
      totalBytes: totalBytes,
      fileCount: inventory.length,
    );
  }

  static Future<AutoBackupCleanupResult> clearAutoBackups() async {
    final files = await _listAutoBackupFiles();
    var deletedFiles = 0;
    var freedBytes = 0;
    for (final file in files) {
      await _deleteAutoBackupFile(file);
      deletedFiles++;
      freedBytes += file.size;
    }
    return AutoBackupCleanupResult(
      deletedFiles: deletedFiles,
      freedBytes: freedBytes,
    );
  }

  static Future<List<_AutoBackupFileEntry>> _listAutoBackupFiles() async {
    if (Platform.isAndroid) {
      final raw = await _SystemBridge.listAutoBackupFiles();
      return raw
          .map((entry) {
            final modifiedMillis = entry["modified"] as int? ?? 0;
            return _AutoBackupFileEntry(
              name: entry["name"] as String? ?? "",
              location: entry["uri"] as String? ?? "",
              size: entry["size"] as int? ?? 0,
              modified: DateTime.fromMillisecondsSinceEpoch(modifiedMillis),
            );
          })
          .where((entry) => entry.name.endsWith(projectExtension))
          .toList();
    }

    final directory = await _ensureAutoBackupDirectory();
    final entries = <_AutoBackupFileEntry>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith(projectExtension)) continue;
      final stat = await entity.stat();
      entries.add(
        _AutoBackupFileEntry(
          name: path.basename(entity.path),
          location: entity.path,
          size: stat.size,
          modified: stat.modified,
        ),
      );
    }
    return entries;
  }

  static Future<void> _deleteAutoBackupFile(_AutoBackupFileEntry entry) async {
    if (Platform.isAndroid) {
      await _SystemBridge.deleteAutoBackupFile(entry.location);
    } else {
      await File(entry.location).delete();
    }
  }

  static Future<void> _pruneAutoBackups({
    required String projectName,
    required int maxTotalBytes,
    required int maxGenerations,
    required Duration maxAge,
  }) async {
    final prefix = "${projectName}_backup_";
    final files =
        (await _listAutoBackupFiles())
            .where((entry) => entry.name.startsWith(prefix))
            .toList()
          ..sort((a, b) => b.modified.compareTo(a.modified));
    final cutoff = DateTime.now().subtract(maxAge);
    var retainedBytes = 0;
    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final exceedsGeneration = index >= maxGenerations;
      final exceedsAge = file.modified.isBefore(cutoff);
      final exceedsBytes = retainedBytes + file.size > maxTotalBytes;
      if (exceedsGeneration || exceedsAge || exceedsBytes) {
        await _deleteAutoBackupFile(file);
      } else {
        retainedBytes += file.size;
      }
    }
  }

  static Future<int?> _availableBackupBytes() async {
    if (Platform.isAndroid) {
      return _SystemBridge.getAvailableBackupBytes();
    }
    try {
      final backupDir = await _ensureAutoBackupDirectory();
      if (Platform.isWindows) {
        final root = path.rootPrefix(backupDir.path).replaceAll("\\", "");
        final result = await Process.run("wmic", [
          "logicaldisk",
          "where",
          "DeviceID='$root'",
          "get",
          "FreeSpace",
          "/value",
        ]);
        final match = RegExp(
          r"FreeSpace=(\d+)",
        ).firstMatch(result.stdout.toString());
        if (match != null) return int.tryParse(match.group(1)!);
        final driveName = root.replaceAll(":", "");
        final fallback = await Process.run("powershell", [
          "-NoProfile",
          "-NonInteractive",
          "-Command",
          "(Get-PSDrive -Name '$driveName').Free",
        ]);
        return int.tryParse(fallback.stdout.toString().trim());
      }
      final result = await Process.run("df", ["-Pk", backupDir.path]);
      final lines = result.stdout.toString().trim().split(RegExp(r"\r?\n"));
      if (lines.length < 2) return null;
      final columns = lines.last.trim().split(RegExp(r"\s+"));
      return columns.length < 4 ? null : (int.tryParse(columns[3]) ?? 0) * 1024;
    } catch (_) {
      return null;
    }
  }

  static Future<String> selectAutoBackupDirectory() async {
    if (Platform.isAndroid) {
      final selectedUri = await _SystemBridge.selectAutoBackupDirectory();
      if (selectedUri == null || selectedUri.trim().isEmpty) {
        throw FileException("已取消選擇 AutoBackup 目錄。");
      }
      return selectedUri;
    }

    final defaultDir = await _defaultAutoBackupDirectory();
    final currentDir = await _autoBackupDirectory();
    final selectedPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "選擇 AutoBackup 目錄",
      initialDirectory: (await currentDir.exists())
          ? currentDir.path
          : defaultDir.parent.path,
    );

    if (selectedPath == null || selectedPath.trim().isEmpty) {
      throw FileException("已取消選擇 AutoBackup 目錄。");
    }

    await _setCustomAutoBackupDirectoryPath(selectedPath);
    final selectedDir = Directory(selectedPath);
    if (!await selectedDir.exists()) {
      await selectedDir.create(recursive: true);
    }
    return selectedDir.path;
  }

  static Future<String> resetAutoBackupDirectory() async {
    if (Platform.isAndroid) {
      throw FileException("Android 需要由使用者選擇 AutoBackup 目錄。");
    }

    await _setCustomAutoBackupDirectoryPath(null);
    final backupDir = await _ensureAutoBackupDirectory();
    return backupDir.path;
  }

  /// 使用平台檔案管理器開啟 AutoBackup 目錄。
  static Future<String> openAutoBackupDirectory() async {
    if (Platform.isAndroid) {
      await _SystemBridge.openSelectedAutoBackupDirectory();
      final selectedUri = await _SystemBridge.getSelectedAutoBackupDirectory();
      return selectedUri ?? "";
    }

    final backupDir = await _ensureAutoBackupDirectory();

    try {
      if (Platform.isWindows) {
        final result = await Process.run("explorer", [backupDir.path]);
        if (result.exitCode == 0) {
          return backupDir.path;
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run("open", [backupDir.path]);
        if (result.exitCode == 0) {
          return backupDir.path;
        }
      } else if (Platform.isLinux) {
        final result = await Process.run("xdg-open", [backupDir.path]);
        if (result.exitCode == 0) {
          return backupDir.path;
        }
      }

      final directoryUri = Uri.directory(
        backupDir.path,
        windows: Platform.isWindows,
      );
      final launched = await launchUrl(
        directoryUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return backupDir.path;
      }
    } catch (e) {
      throw FileException("開啟 AutoBackup 目錄失敗: ${e.toString()}");
    }

    throw FileException("此平台不支援直接開啟 AutoBackup 目錄：${backupDir.path}");
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

  //Mark: --- 本地檔案操作 ---

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

  static String generateProjectXMLWithoutLatestSaveUpdate(ProjectData data) {
    return _ProjectMerger.generateProjectXML(data, updateLatestSave: false);
  }

  /// 解析專案XML內容 (Parser)
  static ProjectData parseProjectXML(String xmlContent) {
    return _ProjectParser.parseProjectXML(xmlContent);
  }

  static ProjectParseResult parseProjectXMLWithMetadata(String xmlContent) {
    return _ProjectParser.parseProjectXMLWithMetadata(xmlContent);
  }
}
