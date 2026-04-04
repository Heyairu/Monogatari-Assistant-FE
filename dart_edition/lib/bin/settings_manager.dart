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

import "dart:convert";

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

class RecentProjectEntry {
  final String fileName;
  final String? filePath;
  final String? uri;
  final int lastOpenedAtMillis;

  const RecentProjectEntry({
    required this.fileName,
    this.filePath,
    this.uri,
    required this.lastOpenedAtMillis,
  });

  bool get canReopen => filePath != null && filePath!.trim().isNotEmpty;

  String get identityKey {
    if (filePath != null && filePath!.trim().isNotEmpty) {
      return "path:${filePath!.trim()}";
    }
    if (uri != null && uri!.trim().isNotEmpty) {
      return "uri:${uri!.trim()}";
    }
    return "name:$fileName";
  }

  String toJsonString() {
    return jsonEncode({
      "fileName": fileName,
      "filePath": filePath,
      "uri": uri,
      "lastOpenedAtMillis": lastOpenedAtMillis,
    });
  }

  static RecentProjectEntry? fromJsonString(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return null;

      final fileName = decoded["fileName"];
      if (fileName is! String || fileName.trim().isEmpty) return null;

      final filePath = decoded["filePath"];
      final uri = decoded["uri"];
      final lastOpenedAtMillis = decoded["lastOpenedAtMillis"];

      return RecentProjectEntry(
        fileName: fileName.trim(),
        filePath: filePath is String && filePath.trim().isNotEmpty
            ? filePath.trim()
            : null,
        uri: uri is String && uri.trim().isNotEmpty ? uri.trim() : null,
        lastOpenedAtMillis: lastOpenedAtMillis is int
            ? lastOpenedAtMillis
            : DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 字數計算模式
enum WordCountMode {
  /// 字元數 (Grapheme Clusters)
  characters,

  /// 全形字元數 + 半形單字數
  wordsAndCharacters,
}

/// 應用設定管理器
class SettingsManager extends ChangeNotifier {
  static const String _showExitWarningKey = "show_exit_warning";
  static const String _fontSizeKey = "app_font_size";
  static const String _wordCountModeKey = "word_count_mode";
  static const String _recentProjectsKey = "recent_projects";
  static const int _maxRecentProjects = 10;
  static const double _defaultFontSize = 12.0;
  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 20.0;

  bool _showExitWarning = true;
  double _fontSize = _defaultFontSize;
  WordCountMode _wordCountMode = WordCountMode.wordsAndCharacters;
  List<RecentProjectEntry> _recentProjects = [];
  bool _isInitialized = false;

  bool get showExitWarning => _showExitWarning;
  double get fontSize => _fontSize;
  WordCountMode get wordCountMode => _wordCountMode;
  List<RecentProjectEntry> get recentProjects =>
      List.unmodifiable(_recentProjects);
  bool get isInitialized => _isInitialized;

  /// 初始化設定管理器
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showExitWarning = prefs.getBool(_showExitWarningKey) ?? true;
      final savedFontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize;
      _fontSize = savedFontSize.clamp(_minFontSize, _maxFontSize);
      final modeIndex =
          prefs.getInt(_wordCountModeKey) ??
          WordCountMode.wordsAndCharacters.index;
      _wordCountMode = WordCountMode.values.length > modeIndex
          ? WordCountMode.values[modeIndex]
          : WordCountMode.wordsAndCharacters;

      final savedRecentProjects =
          prefs.getStringList(_recentProjectsKey) ?? const [];
      _recentProjects =
          savedRecentProjects
              .map(RecentProjectEntry.fromJsonString)
              .whereType<RecentProjectEntry>()
              .toList()
            ..sort(
              (a, b) => b.lastOpenedAtMillis.compareTo(a.lastOpenedAtMillis),
            );

      if (_recentProjects.length > _maxRecentProjects) {
        _recentProjects = _recentProjects.take(_maxRecentProjects).toList();
      }
    } catch (e) {
      _showExitWarning = true;
      _fontSize = _defaultFontSize;
      _wordCountMode = WordCountMode.wordsAndCharacters;
      _recentProjects = [];
      debugPrint("Failed to load settings: $e");
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// 設定是否顯示退出警告
  Future<void> setShowExitWarning(bool value) async {
    if (_showExitWarning != value) {
      _showExitWarning = value;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_showExitWarningKey, value);
      } catch (e) {
        debugPrint("Failed to save exit warning setting: $e");
      }
    }
  }

  /// 設定字體大小
  Future<void> setFontSize(double value) async {
    if (_fontSize != value) {
      _fontSize = value;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_fontSizeKey, value);
      } catch (e) {
        debugPrint("Failed to save font size setting: $e");
      }
    }
  }

  /// 設定字數計算模式
  Future<void> setWordCountMode(WordCountMode value) async {
    if (_wordCountMode != value) {
      _wordCountMode = value;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_wordCountModeKey, value.index);
      } catch (e) {
        debugPrint("Failed to save word count mode setting: $e");
      }
    }
  }

  /// 記錄最近開啟檔案
  Future<void> addRecentProject({
    required String fileName,
    String? filePath,
    String? uri,
  }) async {
    if (fileName.trim().isEmpty) return;

    final entry = RecentProjectEntry(
      fileName: fileName.trim(),
      filePath: filePath?.trim().isNotEmpty == true ? filePath!.trim() : null,
      uri: uri?.trim().isNotEmpty == true ? uri!.trim() : null,
      lastOpenedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    _recentProjects = [
      entry,
      ..._recentProjects.where((item) => item.identityKey != entry.identityKey),
    ];

    if (_recentProjects.length > _maxRecentProjects) {
      _recentProjects = _recentProjects.take(_maxRecentProjects).toList();
    }

    notifyListeners();
    await _saveRecentProjects();
  }

  /// 移除最近開啟檔案
  Future<void> removeRecentProject(RecentProjectEntry entry) async {
    final originalLength = _recentProjects.length;
    _recentProjects = _recentProjects
        .where((item) => item.identityKey != entry.identityKey)
        .toList();

    if (_recentProjects.length != originalLength) {
      notifyListeners();
      await _saveRecentProjects();
    }
  }

  Future<void> _saveRecentProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _recentProjects
          .map((entry) => entry.toJsonString())
          .toList();
      await prefs.setStringList(_recentProjectsKey, encoded);
    } catch (e) {
      debugPrint("Failed to save recent projects: $e");
    }
  }
}
