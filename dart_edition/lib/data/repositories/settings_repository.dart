import "package:shared_preferences/shared_preferences.dart";

import "../../bin/settings_manager.dart";

class SettingsSnapshot {
  final bool showExitWarning;
  final double fontSize;
  final WordCountMode wordCountMode;
  final List<RecentProjectEntry> recentProjects;

  const SettingsSnapshot({
    required this.showExitWarning,
    required this.fontSize,
    required this.wordCountMode,
    required this.recentProjects,
  });
}

abstract class SettingsRepository {
  Future<SettingsSnapshot> load();

  Future<void> saveShowExitWarning(bool value);

  Future<void> saveFontSize(double value);

  Future<void> saveWordCountMode(WordCountMode value);

  Future<void> saveRecentProjects(List<RecentProjectEntry> projects);
}

class SharedPreferencesSettingsRepository implements SettingsRepository {
  static const String _showExitWarningKey = "show_exit_warning";
  static const String _fontSizeKey = "app_font_size";
  static const String _wordCountModeKey = "word_count_mode";
  static const String _recentProjectsKey = "recent_projects";
  static const int _maxRecentProjects = 10;
  static const double _defaultFontSize = 12.0;
  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 20.0;

  @override
  Future<SettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final showExitWarning = prefs.getBool(_showExitWarningKey) ?? true;
    final savedFontSize = prefs.getDouble(_fontSizeKey) ?? _defaultFontSize;
    final fontSize = savedFontSize.clamp(_minFontSize, _maxFontSize);

    final modeIndex =
        prefs.getInt(_wordCountModeKey) ?? WordCountMode.wordsAndCharacters.index;
    final mode = WordCountMode.values.length > modeIndex
        ? WordCountMode.values[modeIndex]
        : WordCountMode.wordsAndCharacters;

    final recentProjectStrings = prefs.getStringList(_recentProjectsKey) ?? const [];
    final recentProjects = recentProjectStrings
        .map(RecentProjectEntry.fromJsonString)
        .whereType<RecentProjectEntry>()
        .toList()
      ..sort((a, b) => b.lastOpenedAtMillis.compareTo(a.lastOpenedAtMillis));

    final trimmedProjects = recentProjects.length > _maxRecentProjects
        ? recentProjects.take(_maxRecentProjects).toList()
        : recentProjects;

    return SettingsSnapshot(
      showExitWarning: showExitWarning,
      fontSize: fontSize,
      wordCountMode: mode,
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
  Future<void> saveRecentProjects(List<RecentProjectEntry> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = projects
        .fold<List<RecentProjectEntry>>([], (acc, item) {
          final exists = acc.any((entry) => entry.identityKey == item.identityKey);
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
