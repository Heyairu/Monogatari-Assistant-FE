import "package:shared_preferences/shared_preferences.dart";

import "../../bin/settings_manager.dart";

class SettingsSnapshot {
  final bool showExitWarning;
  final double fontSize;
  final WordCountMode wordCountMode;
  final bool autoSaveEnabled;
  final int autoSaveIntervalMinutes;
  final bool autoBackupEnabled;
  final int autoBackupIntervalMinutes;
  final List<RecentProjectEntry> recentProjects;

  const SettingsSnapshot({
    required this.showExitWarning,
    required this.fontSize,
    required this.wordCountMode,
    required this.autoSaveEnabled,
    required this.autoSaveIntervalMinutes,
    required this.autoBackupEnabled,
    required this.autoBackupIntervalMinutes,
    required this.recentProjects,
  });
}

abstract class SettingsRepository {
  Future<SettingsSnapshot> load();

  Future<void> saveShowExitWarning(bool value);

  Future<void> saveFontSize(double value);

  Future<void> saveWordCountMode(WordCountMode value);

  Future<void> saveAutoSaveEnabled(bool value);

  Future<void> saveAutoSaveIntervalMinutes(int value);

  Future<void> saveAutoBackupEnabled(bool value);

  Future<void> saveAutoBackupIntervalMinutes(int value);

  Future<void> saveRecentProjects(List<RecentProjectEntry> projects);
}

class SharedPreferencesSettingsRepository implements SettingsRepository {
  static const String _showExitWarningKey = "show_exit_warning";
  static const String _fontSizeKey = "app_font_size";
  static const String _wordCountModeKey = "word_count_mode";
  static const String _autoSaveEnabledKey = "auto_save_enabled";
  static const String _autoSaveIntervalMinutesKey =
      "auto_save_interval_minutes";
  static const String _autoBackupEnabledKey = "auto_backup_enabled";
  static const String _autoBackupIntervalMinutesKey =
      "auto_backup_interval_minutes";
  static const String _legacyAutoBackupEnabledKey = "autosave_enabled";
  static const String _legacyAutoBackupIntervalMinutesKey =
      "autosave_interval_minutes";
  static const String _recentProjectsKey = "recent_projects";
  static const int _maxRecentProjects = 10;
  static const double _defaultFontSize = 12.0;
  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 20.0;
  static const int _defaultAutoSaveIntervalMinutes = 5;
  static const int _minAutoSaveIntervalMinutes = 1;
  static const int _maxAutoSaveIntervalMinutes = 120;
  static const int _defaultAutoBackupIntervalMinutes = 5;
  static const int _minAutoBackupIntervalMinutes = 1;
  static const int _maxAutoBackupIntervalMinutes = 120;

  @override
  Future<SettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final showExitWarning = prefs.getBool(_showExitWarningKey) ?? true;
    final savedFontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize;
    final fontSize = savedFontSize.clamp(_minFontSize, _maxFontSize);

    final modeIndex =
        prefs.getInt(_wordCountModeKey) ??
        WordCountMode.wordsAndCharacters.index;
    final mode = WordCountMode.values.length > modeIndex
        ? WordCountMode.values[modeIndex]
        : WordCountMode.wordsAndCharacters;
    final autoSaveEnabled = prefs.getBool(_autoSaveEnabledKey) ?? false;
    final autoSaveIntervalMinutes =
        (prefs.getInt(_autoSaveIntervalMinutesKey) ??
                _defaultAutoSaveIntervalMinutes)
            .clamp(_minAutoSaveIntervalMinutes, _maxAutoSaveIntervalMinutes);
    final autoBackupEnabled =
        prefs.getBool(_autoBackupEnabledKey) ??
        prefs.getBool(_legacyAutoBackupEnabledKey) ??
        false;
    final autoBackupIntervalMinutes =
        (prefs.getInt(_autoBackupIntervalMinutesKey) ??
                prefs.getInt(_legacyAutoBackupIntervalMinutesKey) ??
                _defaultAutoBackupIntervalMinutes)
            .clamp(
              _minAutoBackupIntervalMinutes,
              _maxAutoBackupIntervalMinutes,
            );

    final recentProjectStrings =
        prefs.getStringList(_recentProjectsKey) ?? const [];
    final recentProjects =
        recentProjectStrings
            .map(RecentProjectEntry.fromJsonString)
            .whereType<RecentProjectEntry>()
            .toList()
          ..sort(
            (a, b) => b.lastOpenedAtMillis.compareTo(a.lastOpenedAtMillis),
          );

    final trimmedProjects = recentProjects.length > _maxRecentProjects
        ? recentProjects.take(_maxRecentProjects).toList()
        : recentProjects;

    return SettingsSnapshot(
      showExitWarning: showExitWarning,
      fontSize: fontSize,
      wordCountMode: mode,
      autoSaveEnabled: autoSaveEnabled,
      autoSaveIntervalMinutes: autoSaveIntervalMinutes,
      autoBackupEnabled: autoBackupEnabled,
      autoBackupIntervalMinutes: autoBackupIntervalMinutes,
      recentProjects: trimmedProjects,
    );
  }

  @override
  Future<void> saveShowExitWarning(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showExitWarningKey, value);
  }

  @override
  Future<void> saveFontSize(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, value);
  }

  @override
  Future<void> saveWordCountMode(WordCountMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_wordCountModeKey, value.index);
  }

  @override
  Future<void> saveAutoSaveEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSaveEnabledKey, value);
  }

  @override
  Future<void> saveAutoSaveIntervalMinutes(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _autoSaveIntervalMinutesKey,
      value.clamp(_minAutoSaveIntervalMinutes, _maxAutoSaveIntervalMinutes),
    );
  }

  @override
  Future<void> saveAutoBackupEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupEnabledKey, value);
  }

  @override
  Future<void> saveAutoBackupIntervalMinutes(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _autoBackupIntervalMinutesKey,
      value.clamp(_minAutoBackupIntervalMinutes, _maxAutoBackupIntervalMinutes),
    );
  }

  @override
  Future<void> saveRecentProjects(List<RecentProjectEntry> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = projects
        .fold<List<RecentProjectEntry>>([], (acc, item) {
          final exists = acc.any(
            (entry) => entry.identityKey == item.identityKey,
          );
          if (!exists) {
            acc.add(item);
          }
          return acc;
        })
        .take(_maxRecentProjects)
        .toList();

    await prefs.setStringList(
      _recentProjectsKey,
      normalized.map((entry) => entry.toJsonString()).toList(),
    );
  }
}
