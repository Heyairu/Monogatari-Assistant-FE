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

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

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
  
  bool _showExitWarning = true;
  double _fontSize = 14.0;
  WordCountMode _wordCountMode = WordCountMode.wordsAndCharacters;
  bool _isInitialized = false;
  
  bool get showExitWarning => _showExitWarning;
  double get fontSize => _fontSize;
  WordCountMode get wordCountMode => _wordCountMode;
  bool get isInitialized => _isInitialized;
  
  /// 初始化設定管理器
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showExitWarning = prefs.getBool(_showExitWarningKey) ?? true;
      _fontSize = prefs.getDouble(_fontSizeKey) ?? 14.0;
      final modeIndex = prefs.getInt(_wordCountModeKey) ?? WordCountMode.wordsAndCharacters.index;
      _wordCountMode = WordCountMode.values.length > modeIndex 
          ? WordCountMode.values[modeIndex] 
          : WordCountMode.wordsAndCharacters;
    } catch (e) {
      _showExitWarning = true;
      _fontSize = 14.0;
      _wordCountMode = WordCountMode.wordsAndCharacters;
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
}
