import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../bin/settings_manager.dart";
import "../../bin/ui_library.dart";
import "../../models/app_state_data.dart";
import "core_providers.dart";

export "../../models/app_state_data.dart";

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
      autoSaveEnabled: snapshot.autoSaveEnabled,
      autoSaveIntervalMinutes: snapshot.autoSaveIntervalMinutes,
      autoBackupEnabled: snapshot.autoBackupEnabled,
      autoBackupIntervalMinutes: snapshot.autoBackupIntervalMinutes,
      autoBackupMaxSizeMb: snapshot.autoBackupMaxSizeMb,
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

  Future<void> setAutoSaveEnabled(bool value) async {
    final current = state.valueOrNull ?? const AppSettingsStateData();
    state = AsyncData(current.copyWith(autoSaveEnabled: value));
    await ref.read(settingsRepositoryProvider).saveAutoSaveEnabled(value);
  }

  Future<void> setAutoSaveIntervalMinutes(int value) async {
    final normalized = value.clamp(1, 120);
    final current = state.valueOrNull ?? const AppSettingsStateData();
    state = AsyncData(current.copyWith(autoSaveIntervalMinutes: normalized));
    await ref
        .read(settingsRepositoryProvider)
        .saveAutoSaveIntervalMinutes(normalized);
  }

  Future<void> setAutoBackupEnabled(bool value) async {
    final current = state.valueOrNull ?? const AppSettingsStateData();
    state = AsyncData(current.copyWith(autoBackupEnabled: value));
    await ref.read(settingsRepositoryProvider).saveAutoBackupEnabled(value);
  }

  Future<void> setAutoBackupIntervalMinutes(int value) async {
    final normalized = value.clamp(1, 120);
    final current = state.valueOrNull ?? const AppSettingsStateData();
    state = AsyncData(current.copyWith(autoBackupIntervalMinutes: normalized));
    await ref
        .read(settingsRepositoryProvider)
        .saveAutoBackupIntervalMinutes(normalized);
  }

  Future<void> setAutoBackupMaxSizeMb(int value) async {
    final normalized = value.clamp(16, 10240);
    final current = state.valueOrNull ?? const AppSettingsStateData();
    state = AsyncData(current.copyWith(autoBackupMaxSizeMb: normalized));
    await ref
        .read(settingsRepositoryProvider)
        .saveAutoBackupMaxSizeMb(normalized);
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
      ...current.recentProjects.where(
        (item) => item.identityKey != entry.identityKey,
      ),
    ];
    final nextRecentProjects = merged.take(_maxRecentProjects).toList();

    state = AsyncData(current.copyWith(recentProjects: nextRecentProjects));
    await ref
        .read(settingsRepositoryProvider)
        .saveRecentProjects(nextRecentProjects);
  }

  Future<void> removeRecentProject(RecentProjectEntry entry) async {
    final current = state.valueOrNull ?? const AppSettingsStateData();
    final nextRecentProjects = current.recentProjects
        .where((item) => item.identityKey != entry.identityKey)
        .toList();

    state = AsyncData(current.copyWith(recentProjects: nextRecentProjects));
    await ref
        .read(settingsRepositoryProvider)
        .saveRecentProjects(nextRecentProjects);
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

@immutable
class AppThemeSettings {
  final Color color;
  final AppThemeMode mode;
  final double fontSize;

  const AppThemeSettings({
    required this.color,
    required this.mode,
    required this.fontSize,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppThemeSettings &&
            other.color == color &&
            other.mode == mode &&
            other.fontSize == fontSize;
  }

  @override
  int get hashCode => Object.hash(color, mode, fontSize);
}

final appThemeSettingsProvider = Provider<AppThemeSettings>((ref) {
  final theme = ref.watch(
    themeStateProvider.select(
      (state) => state.valueOrNull ?? const AppThemeStateData(),
    ),
  );
  final fontSize = ref.watch(
    settingsStateProvider.select(
      (state) => state.valueOrNull?.fontSize ?? 12.0,
    ),
  );

  return AppThemeSettings(
    color: theme.themeColor,
    mode: theme.themeMode,
    fontSize: fontSize,
  );
});

final appInitializationProvider = FutureProvider<void>((ref) async {
  await Future.wait([
    // Bootstrap should only await initial load; later updates should not
    // re-enter app-level loading and replace the whole UI tree.
    ref.read(themeStateProvider.future),
    ref.read(settingsStateProvider.future),
  ]);
});
