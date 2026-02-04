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
import "package:flutter/scheduler.dart";
import "package:shared_preferences/shared_preferences.dart";

/// 主題模式枚舉
enum AppThemeMode {
  light,
  dark,
  system,
}

/// 主題管理器 - 管理應用的主題狀態
class UILibrary extends ChangeNotifier {
  static const String _themePreferenceKey = "app_theme_mode";
  static const String _colorPreferenceKey = "app_theme_color";
  
  AppThemeMode _themeMode = AppThemeMode.system;
  Color _themeColor = Colors.lightBlue; // Default color
  bool _isInitialized = false;
  
  AppThemeMode get themeMode => _themeMode;
  Color get themeColor => _themeColor;
  bool get isInitialized => _isInitialized;

  // Supported colors
  static const Map<String, Color> supportedColors = {
    "Auto": Colors.lightBlue,
    "Gray": Colors.grey,
    "Red": Colors.red,
    "Orange": Colors.orange,
    "Yellow": Colors.amber,
    "Green": Colors.green,
    "Cyan": Colors.cyan,
    "Blue": Colors.blue,
    "Purple": Colors.purple,
    "Pink": Colors.pink,
  };
  
  /// 初始化主題管理器 - 從儲存中載入主題設定
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Theme Mode
      final savedThemeIndex = prefs.getInt(_themePreferenceKey);
      if (savedThemeIndex != null && savedThemeIndex >= 0 && savedThemeIndex < AppThemeMode.values.length) {
        _themeMode = AppThemeMode.values[savedThemeIndex];
      }

      // Load Theme Color
      final savedColorValue = prefs.getInt(_colorPreferenceKey);
      if (savedColorValue != null) {
        _themeColor = Color(savedColorValue);
      }

    } catch (e) {
      // 如果載入失敗，使用預設值
      _themeMode = AppThemeMode.system;
      _themeColor = Colors.lightBlue;
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

  /// 設置主題顏色並儲存
  Future<void> setThemeColor(Color color) async {
    if (_themeColor != color) {
      _themeColor = color;
      notifyListeners();
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_colorPreferenceKey, color.value);
      } catch (e) {
        debugPrint("Failed to save theme color: $e");
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
  /// 生成 TextTheme
  static TextTheme _buildTextTheme(double baseSize) {
    return TextTheme(
      // L1 +12px
      displayLarge: TextStyle(fontSize: baseSize + 12, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontSize: baseSize + 12, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontSize: baseSize + 12, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(fontSize: baseSize + 12, fontWeight: FontWeight.bold),
      
      // L2 +8px
      headlineMedium: TextStyle(fontSize: baseSize + 8, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: baseSize + 8, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: baseSize + 8, fontWeight: FontWeight.w600),
      
      // L3 +4px
      titleMedium: TextStyle(fontSize: baseSize + 4, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: baseSize + 4, fontWeight: FontWeight.w500),
      
      // Body (base)
      bodyLarge: TextStyle(fontSize: baseSize),
      bodyMedium: TextStyle(fontSize: baseSize),
      
      // Subtitle/Status -4px
      bodySmall: TextStyle(fontSize: baseSize - 4),
      labelLarge: TextStyle(fontSize: baseSize - 4),
      labelMedium: TextStyle(fontSize: baseSize - 4),
      labelSmall: TextStyle(fontSize: baseSize - 4),
    );
  }

  /// 獲取淺色主題
  static ThemeData getLightTheme(double baseFontSize, Color seedColor) {
    ColorScheme colorScheme;
    
    // 特殊處理灰色：手動構建灰階 ColorScheme
    if (seedColor.value == Colors.grey.value) {
      colorScheme = const ColorScheme.light(
        primary: Color(0xFF616161),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE0E0E0),
        onPrimaryContainer: Color(0xFF212121),
        secondary: Color(0xFF757575),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFEEEEEE),
        onSecondaryContainer: Color(0xFF212121),
        tertiary: Color(0xFF9E9E9E),
        onTertiary: Colors.black,
        tertiaryContainer: Color(0xFFF5F5F5),
        onTertiaryContainer: Color(0xFF212121),
        surface: Color(0xFFFAFAFA),
        onSurface: Color(0xFF212121),
        surfaceContainerHighest: Color(0xFFE0E0E0),
      );
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      );
    }
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(baseFontSize),
      iconTheme: IconThemeData(
        size: baseFontSize + 10,
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
  
  /// 獲取深色主題
  static ThemeData getDarkTheme(double baseFontSize, Color seedColor) {
    ColorScheme colorScheme;
    
    // 特殊處理灰色：手動構建灰階 ColorScheme
    if (seedColor.value == Colors.grey.value) {
      colorScheme = const ColorScheme.dark(
        primary: Color(0xFFE0E0E0),
        onPrimary: Color(0xFF212121),
        primaryContainer: Color(0xFF424242),
        onPrimaryContainer: Color(0xFFE0E0E0),
        secondary: Color(0xFFBDBDBD),
        onSecondary: Color(0xFF212121),
        secondaryContainer: Color(0xFF616161),
        onSecondaryContainer: Color(0xFFEEEEEE),
        tertiary: Color(0xFF9E9E9E),
        onTertiary: Colors.black,
        tertiaryContainer: Color(0xFF757575),
        onTertiaryContainer: Color(0xFFEEEEEE),
        surface: Color(0xFF121212),
        onSurface: Color(0xFFE0E0E0),
        surfaceContainerHighest: Color(0xFF424242),
      );
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      );
    }
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(baseFontSize),
      iconTheme: IconThemeData(
        size: baseFontSize + 10,
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
}

// MARK: - 通用元件

// 新增項目元件
class AddItemInput extends StatefulWidget {
  final String title;
  final ValueChanged<String> onAdd;
  final TextEditingController? controller;
  final bool allowEmpty;
  final bool enabled;

  const AddItemInput({
    super.key,
    required this.title,
    required this.onAdd,
    this.controller,
    this.allowEmpty = false,
    this.enabled = true,
  });

  @override
  State<AddItemInput> createState() => _AddItemInputState();
}

class _AddItemInputState extends State<AddItemInput> {
  late final TextEditingController _controller;
  bool _isInternalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _isInternalController = true;
    }
  }

  @override
  void dispose() {
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleAdd() {
    final value = _controller.text.trim();
    if ((widget.allowEmpty || value.isNotEmpty) && widget.enabled) {
      widget.onAdd(value);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            decoration: InputDecoration(
              hintText: widget.enabled ? "新增${widget.title}" : widget.title,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (value) {
               if (widget.enabled && (widget.allowEmpty || value.trim().isNotEmpty)) {
                 _handleAdd();
               }
            },
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, child) {
            final text = value.text.trim();
            final bool canAdd = widget.enabled && (widget.allowEmpty || text.isNotEmpty);
            
            return IconButton(
              onPressed: canAdd ? _handleAdd : null,
              icon: Icon(
                Icons.add_circle,
                color: canAdd ? Colors.green : Colors.grey,
              ),
              tooltip: "新增${widget.title}",
            );
          },
        ),
      ],
    );
  }
}

// Chip 元件
class CardList extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;

  const CardList({
    super.key,
    required this.title,
    required this.icon,
    this.items = const [],
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 現有項目
        if (items.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Chip(
                label: Text(item),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => onRemove(index),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // 新增項目
        AddItemInput(
           title: title,
           onAdd: onAdd,
        ),
      ],
    );
  }
}


