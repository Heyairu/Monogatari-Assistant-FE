import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../bin/settings_manager.dart";
import "../../bin/ui_library.dart";
import "core_providers.dart";

class AppThemeStateData {
  final AppThemeMode themeMode;
  final Color themeColor;

  const AppThemeStateData({
    this.themeMode = AppThemeMode.system,
    this.themeColor = Colors.lightBlue,
  });

  AppThemeStateData copyWith({
    AppThemeMode? themeMode,
    Color? themeColor,
  }) {
    return AppThemeStateData(
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
    );
  }
}

class AppSettingsStateData {
  final bool showExitWarning;
  final double fontSize;
  final WordCountMode wordCountMode;
  final List<RecentProjectEntry> recentProjects;

  const AppSettingsStateData({
    this.showExitWarning = true,
    this.fontSize = 12.0,
    this.wordCountMode = WordCountMode.wordsAndCharacters,
    this.recentProjects = const [],
  });

  AppSettingsStateData copyWith({
    bool? showExitWarning,
    double? fontSize,
    WordCountMode? wordCountMode,
    List<RecentProjectEntry>? recentProjects,
  }) {
    return AppSettingsStateData(
      showExitWarning: showExitWarning ?? this.showExitWarning,
      fontSize: fontSize ?? this.fontSize,
      wordCountMode: wordCountMode ?? this.wordCountMode,
      recentProjects: recentProjects ?? this.recentProjects,
    );
  }
}

class ThemeStateNotifier extends AsyncNotifier<AppThemeStateData> {
  @override
  Future<AppThemeStateData> build() async {
    final repository = ref.read(themeRepositoryProvider);
    final snapshot = await repository.load();
    return AppThemeStateData(
      themeMode: snapshot.themeMode,
      themeColor: snapshot.themeColor,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final current = state.valueOrNull ?? const AppThemeStateData();
    state = AsyncData(current.copyWith(themeMode: mode));
    await ref.read(themeRepositoryProvider).saveThemeMode(mode);
  }

  Future<void> setThemeColor(Color color) async {
    final current = state.valueOrNull ?? const AppThemeStateData();
    state = AsyncData(current.copyWith(themeColor: color));
    await ref.read(themeRepositoryProvider).saveThemeColor(color);
  }

  Future<void> toggleTheme() async {
    final current = state.valueOrNull ?? const AppThemeStateData();
    switch (current.themeMode) {
      case AppThemeMode.light:
        await setThemeMode(AppThemeMode.dark);
        break;
      case AppThemeMode.dark:
        await setThemeMode(AppThemeMode.system);
        break;
      case AppThemeMode.system:
        await setThemeMode(AppThemeMode.light);
        break;
    }
  }
}

class SettingsStateNotifier extends AsyncNotifier<AppSettingsStateData> {
  static const int _maxRecentProjects = 10;

  @override
  Future<AppSettingsStateData> build() async {
    final repository = ref.read(settingsRepositoryProvider);
    final snapshot = await repository.load();

    return AppSettingsStateData(
      showExitWarning: snapshot.showExitWarning,
      fontSize: snapshot.fontSize,
      wordCountMode: snapshot.wordCountMode,
      recentProjects: snapshot.recentProjects,
    );
  }

  Future<void> setShowExitWarning(bool value) async {
    final current = state.valueOrNull ?? const AppSettingsStateData();
    state = AsyncData(current.copyWith(showExitWarning: value));
    await ref.read(settingsRepositoryProvider).saveShowExitWarning(value);
  }

  Future<void> setFontSize(double value) async {
    final current = state.valueOrNull ?? const AppSettingsStateData();
    state = AsyncData(current.copyWith(fontSize: value));
    await ref.read(settingsRepositoryProvider).saveFontSize(value);
  }

  Future<void> setWordCountMode(WordCountMode value) async {
    final current = state.valueOrNull ?? const AppSettingsStateData();
    state = AsyncData(current.copyWith(wordCountMode: value));
    await ref.read(settingsRepositoryProvider).saveWordCountMode(value);
  }

  Future<void> addRecentProject({
    required String fileName,
    String? filePath,
    String? uri,
  }) async {
    final current = state.valueOrNull ?? const AppSettingsStateData();
    if (fileName.trim().isEmpty) {
      return;
    }

    final entry = RecentProjectEntry(
      fileName: fileName.trim(),
      filePath: filePath?.trim().isNotEmpty == true ? filePath!.trim() : null,
      uri: uri?.trim().isNotEmpty == true ? uri!.trim() : null,
      lastOpenedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    final merged = [
      entry,
      ...current.recentProjects.where((item) => item.identityKey != entry.identityKey),
    ];
    final nextRecentProjects = merged.take(_maxRecentProjects).toList();

    state = AsyncData(current.copyWith(recentProjects: nextRecentProjects));
    await ref.read(settingsRepositoryProvider).saveRecentProjects(nextRecentProjects);
  }

  Future<void> removeRecentProject(RecentProjectEntry entry) async {
    final current = state.valueOrNull ?? const AppSettingsStateData();
    final nextRecentProjects = current.recentProjects
        .where((item) => item.identityKey != entry.identityKey)
        .toList();

    state = AsyncData(current.copyWith(recentProjects: nextRecentProjects));
    await ref.read(settingsRepositoryProvider).saveRecentProjects(nextRecentProjects);
  }
}

final themeStateProvider =
    AsyncNotifierProvider<ThemeStateNotifier, AppThemeStateData>(
      ThemeStateNotifier.new,
    );

final settingsStateProvider =
    AsyncNotifierProvider<SettingsStateNotifier, AppSettingsStateData>(
      SettingsStateNotifier.new,
    );

final appInitializationProvider = FutureProvider<void>((ref) async {
  await Future.wait([
    ref.watch(themeStateProvider.future),
    ref.watch(settingsStateProvider.future),
  ]);
});
