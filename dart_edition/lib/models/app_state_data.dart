import "package:flutter/material.dart";
import "package:freezed_annotation/freezed_annotation.dart";

import "../bin/settings_manager.dart";
import "../bin/ui_library.dart";

part "app_state_data.freezed.dart";

@freezed
class AppThemeStateData with _$AppThemeStateData {
  const factory AppThemeStateData({
    @Default(AppThemeMode.system) AppThemeMode themeMode,
    @Default(Colors.lightBlue) Color themeColor,
  }) = _AppThemeStateData;
}

@freezed
class AppSettingsStateData with _$AppSettingsStateData {
  const factory AppSettingsStateData({
    @Default(true) bool showExitWarning,
    @Default(12.0) double fontSize,
    @Default(WordCountMode.wordsAndCharacters) WordCountMode wordCountMode,
    @Default(<RecentProjectEntry>[]) List<RecentProjectEntry> recentProjects,
  }) = _AppSettingsStateData;
}
