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

/// 應用設定管理器
class SettingsManager extends ChangeNotifier {
  static const String _showExitWarningKey = "show_exit_warning";
  
  bool _showExitWarning = true;
  bool _isInitialized = false;
  
  bool get showExitWarning => _showExitWarning;
  bool get isInitialized => _isInitialized;
  
  /// 初始化設定管理器
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showExitWarning = prefs.getBool(_showExitWarningKey) ?? true;
    } catch (e) {
      _showExitWarning = true;
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
}
