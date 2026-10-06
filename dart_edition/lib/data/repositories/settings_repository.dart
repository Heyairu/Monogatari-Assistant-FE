import "package:shared_preferences/shared_preferences.dart";

import "../../bin/settings_manager.dart";
import "../../models/navigation_style.dart";

class SettingsSnapshot {
  final NavigationStyle navigationStyle;
  final bool showExitWarning;
  final double fontSize;
  final WordCountMode wordCountMode;
  final bool autoSaveEnabled;
  final int autoSaveIntervalMinutes;
  final bool autoBackupEnabled;
  final int autoBackupIntervalMinutes;
  final int autoBackupMaxSizeMb;
  final bool allowSingleDevicePairingConfirmation;
  final bool allowPersistentP2pVerification;
  final bool poppinEnabled;
  final bool overwriteModeEnabled;
  final int tabSpaceCount;
  final bool tabFullWidth;
  final bool autoIndentLineStart;
  final List<RecentProjectEntry> recentProjects;

  const SettingsSnapshot({
    this.navigationStyle = NavigationStyle.railLabel,
    required this.showExitWarning,
    required this.fontSize,
    required this.wordCountMode,
    required this.autoSaveEnabled,
    required this.autoSaveIntervalMinutes,
    required this.autoBackupEnabled,
    required this.autoBackupIntervalMinutes,
    required this.autoBackupMaxSizeMb,
    required this.allowSingleDevicePairingConfirmation,
    required this.allowPersistentP2pVerification,
    required this.poppinEnabled,
    this.overwriteModeEnabled = true,
    this.tabSpaceCount = 2,
    this.tabFullWidth = true,
    this.autoIndentLineStart = false,
    required this.recentProjects,
  });
}

abstract class SettingsRepository {
  Future<SettingsSnapshot> load();

  Future<void> saveNavigationStyle(NavigationStyle value);

  Future<void> saveShowExitWarning(bool value);

  Future<void> saveFontSize(double value);

  Future<void> saveWordCountMode(WordCountMode value);

  Future<void> saveAutoSaveEnabled(bool value);

  Future<void> saveAutoSaveIntervalMinutes(int value);

  Future<void> saveAutoBackupEnabled(bool value);

  Future<void> saveAutoBackupIntervalMinutes(int value);

  Future<void> saveAutoBackupMaxSizeMb(int value);

  Future<void> saveAllowSingleDevicePairingConfirmation(bool value);

  Future<void> saveAllowPersistentP2pVerification(bool value);

  Future<void> savePoppinEnabled(bool value);

  Future<void> saveOverwriteModeEnabled(bool value);

  Future<void> saveTabSpaceCount(int value);
  Future<void> saveTabFullWidth(bool value);
  Future<void> saveAutoIndentLineStart(bool value);

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
  static const String _autoBackupMaxSizeMbKey = "auto_backup_max_size_mb";
  static const String _allowSingleDevicePairingConfirmationKey =
      "p2p_allow_single_device_pairing_confirmation";
  static const String _allowPersistentP2pVerificationKey =
      "p2p_allow_persistent_verification";
  static const String _poppinEnabledKey = "poppin_enabled";
  static const String _legacyAutoBackupEnabledKey = "autosave_enabled";
  static const String _legacyAutoBackupIntervalMinutesKey =
      "autosave_interval_minutes";
  static const String _recentProjectsKey = "recent_projects";
  static const int _maxRecentProjects = 10;
  static const double _defaultFontSize = 14.0;
  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 20.0;
  static const int _defaultAutoSaveIntervalMinutes = 5;
  static const int _minAutoSaveIntervalMinutes = 1;
  static const int _maxAutoSaveIntervalMinutes = 120;
  static const int _defaultAutoBackupIntervalMinutes = 5;
  static const int _minAutoBackupIntervalMinutes = 1;
  static const int _maxAutoBackupIntervalMinutes = 120;
  static const int _defaultAutoBackupMaxSizeMb = 512;
  static const int _minAutoBackupMaxSizeMb = 16;
  static const int _maxAutoBackupMaxSizeMb = 10240;

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
    final autoBackupMaxSizeMb =
        (prefs.getInt(_autoBackupMaxSizeMbKey) ?? _defaultAutoBackupMaxSizeMb)
            .clamp(_minAutoBackupMaxSizeMb, _maxAutoBackupMaxSizeMb);
    final allowSingleDevicePairingConfirmation =
        prefs.getBool(_allowSingleDevicePairingConfirmationKey) ?? true;
    final allowPersistentP2pVerification =
        prefs.getBool(_allowPersistentP2pVerificationKey) ?? false;
    final poppinEnabled = prefs.getBool(_poppinEnabledKey) ?? true;

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
      navigationStyle: NavigationStyle.fromPreference(
        prefs.getString("navigation_style"),
      ),
      showExitWarning: showExitWarning,
      fontSize: fontSize,
      wordCountMode: mode,
      autoSaveEnabled: autoSaveEnabled,
      autoSaveIntervalMinutes: autoSaveIntervalMinutes,
      autoBackupEnabled: autoBackupEnabled,
      autoBackupIntervalMinutes: autoBackupIntervalMinutes,
      autoBackupMaxSizeMb: autoBackupMaxSizeMb,
      allowSingleDevicePairingConfirmation:
          allowSingleDevicePairingConfirmation,
      allowPersistentP2pVerification: allowPersistentP2pVerification,
      poppinEnabled: poppinEnabled,
      overwriteModeEnabled:
          prefs.getBool("editor_overwrite_mode_enabled") ?? true,
      tabSpaceCount: (prefs.getInt("editor_tab_space_count") ?? 2).clamp(1, 8),
      tabFullWidth: prefs.getBool("editor_tab_full_width") ?? true,
      autoIndentLineStart:
          prefs.getBool("editor_auto_indent_line_start") ?? false,
      recentProjects: trimmedProjects,
    );
  }

  @override
  Future<void> saveNavigationStyle(NavigationStyle value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("navigation_style", value.name);
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
  Future<void> saveAutoBackupMaxSizeMb(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _autoBackupMaxSizeMbKey,
      value.clamp(_minAutoBackupMaxSizeMb, _maxAutoBackupMaxSizeMb),
    );
  }

  @override
  Future<void> saveAllowSingleDevicePairingConfirmation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_allowSingleDevicePairingConfirmationKey, value);
  }

  @override
  Future<void> saveAllowPersistentP2pVerification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_allowPersistentP2pVerificationKey, value);
  }

  @override
  Future<void> savePoppinEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_poppinEnabledKey, value);
  }

  @override
  Future<void> saveOverwriteModeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("editor_overwrite_mode_enabled", value);
  }

  @override
  Future<void> saveTabSpaceCount(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("editor_tab_space_count", value.clamp(1, 8));
  }

  @override
  Future<void> saveTabFullWidth(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("editor_tab_full_width", value);
  }

  @override
  Future<void> saveAutoIndentLineStart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("editor_auto_indent_line_start", value);
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
