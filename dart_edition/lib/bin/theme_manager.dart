import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 主題模式枚舉
enum AppThemeMode {
  light,
  dark,
  system,
}

/// 主題管理器 - 管理應用的主題狀態
class ThemeManager extends ChangeNotifier {
  static const String _themePreferenceKey = "app_theme_mode";
  
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _isInitialized = false;
  
  AppThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  
  /// 初始化主題管理器 - 從儲存中載入主題設定
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeIndex = prefs.getInt(_themePreferenceKey);
      
      if (savedThemeIndex != null && savedThemeIndex >= 0 && savedThemeIndex < AppThemeMode.values.length) {
        _themeMode = AppThemeMode.values[savedThemeIndex];
      }
    } catch (e) {
      // 如果載入失敗，使用預設值
      _themeMode = AppThemeMode.system;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  /// 獲取實際使用的亮度（考慮系統主題）
  Brightness get effectiveBrightness {
    if (_themeMode == AppThemeMode.system) {
      // 獲取系統主題
      final brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
      return brightness;
    }
    return _themeMode == AppThemeMode.dark ? Brightness.dark : Brightness.light;
  }
  
  /// 是否為暗色模式
  bool get isDarkMode => effectiveBrightness == Brightness.dark;
  
  /// 設置主題模式並儲存
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      
      // 儲存到 SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_themePreferenceKey, mode.index);
      } catch (e) {
        // 儲存失敗時不影響主題切換功能
        debugPrint("Failed to save theme preference: $e");
      }
    }
  }
  
  /// 切換主題
  Future<void> toggleTheme() async {
    switch (_themeMode) {
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

/// 主題配色方案
class AppTheme {
  /// 淺色主題
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.lightBlue,
      brightness: Brightness.light,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
  
  /// 深色主題
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.lightBlue,
      brightness: Brightness.dark,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}
