/************************************************************
 * 
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 ************************************************************/

import "dart:ui" as ui;
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../ui_library/spacing.dart";
import "../ui_library/control_shape.dart";
import "../ui_library/control_size.dart";
import "../ui_library/surface_shape.dart";
import "../ui_library/forms.dart";
import "../ui_library/collections.dart";
import "../ui_library/list_style.dart";
import "../ui_library/neon_icon_button.dart";
import "../ui_library/neon_ui_theme.dart";

export "../ui_library/collections.dart";
export "../ui_library/control_shape.dart";
export "../ui_library/control_size.dart";
export "../ui_library/spacing.dart";
export "../ui_library/dialogs.dart";
export "../ui_library/feedback.dart";
export "../ui_library/forms.dart";
export "../ui_library/layout.dart";
export "../ui_library/list_style.dart";
export "../ui_library/mini_timeline.dart";
export "../ui_library/menu_button.dart";
export "../ui_library/neon_icon_button.dart";
export "../ui_library/neon_status_icon.dart";
export "../ui_library/neon_ui_theme.dart";
export "../ui_library/surface_shape.dart";
export "../ui_library/tables.dart";

/// 主題模式枚舉
enum AppThemeMode { light, dark, system }

/// App-specific compact labels below Material 3's smallest `labelSmall` role.
/// They inherit its color, font, weight and the user's preferred font scale.
extension AppTextTheme on TextTheme {
  TextStyle? get labelTiny => _compactLabel(10);
  TextStyle? get labelNano => _compactLabel(9);

  TextStyle? _compactLabel(double baseSize) {
    final base = labelSmall;
    if (base == null) return null;
    return base.copyWith(fontSize: (base.fontSize ?? 11) * baseSize / 11);
  }
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
      if (savedThemeIndex != null &&
          savedThemeIndex >= 0 &&
          savedThemeIndex < AppThemeMode.values.length) {
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
      final brightness =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
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
  static const _controlShape = RoundedRectangleBorder(
    borderRadius: AppControlShape.borderRadius,
  );

  static OutlinedBorder _iconButtonShape(Set<WidgetState> states) =>
      states.contains(WidgetState.hovered)
      ? const CircleBorder()
      : _controlShape;

  static ButtonStyle _buttonStyle(double baseFontSize) => ButtonStyle(
    visualDensity: VisualDensity.standard,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      AppSpacing.buttonPadding,
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(_controlShape),
    minimumSize: WidgetStatePropertyAll<Size>(
      Size(
        AppControlSize.buttonMinWidth,
        AppControlSize.heightForFontSize(baseFontSize),
      ),
    ),
  );

  /// 根據當前系統語言決定字體
  static String get _primaryFontFamily {
    final locale = ui.PlatformDispatcher.instance.locale;
    final lang = locale.languageCode;
    final country = locale.countryCode;

    if (lang == "zh") {
      if (country == "HK") return "NotoSansHK";
      if (country == "TW" || country == "MO") return "NotoSansTC";
      return "NotoSansSC";
    } else if (lang == "ja") {
      return "NotoSansJP";
    } else if (lang == "ko") {
      return "NotoSansKR";
    } else if (lang == "th") {
      return "NotoSansThai";
    }
    return "NotoSans";
  }

  /// 字體回退列表 (保證不論選擇哪種字體，其他語言的字元也能顯示)
  static const List<String> _fontFamilyFallback = [
    "NotoSans",
    "NotoSansTC",
    "NotoSansSC",
    "NotoSansJP",
    "NotoSansKR",
    "NotoSansHK",
    "NotoSansThai",
  ];

  /// Scale Material 3 type roles around its 14sp bodyMedium size.
  /// ThemeData supplies each role's Material 3 weight, line height and spacing.
  static TextTheme _buildTextTheme(double bodyMediumSize) {
    final scale = bodyMediumSize / 14.0;
    return TextTheme(
      displayLarge: TextStyle(fontSize: 57 * scale),
      displayMedium: TextStyle(fontSize: 45 * scale),
      displaySmall: TextStyle(fontSize: 36 * scale),
      headlineLarge: TextStyle(fontSize: 32 * scale),
      headlineMedium: TextStyle(fontSize: 28 * scale),
      headlineSmall: TextStyle(fontSize: 24 * scale),
      titleLarge: TextStyle(fontSize: 22 * scale),
      titleMedium: TextStyle(fontSize: 16 * scale),
      titleSmall: TextStyle(fontSize: 14 * scale),
      bodyLarge: TextStyle(fontSize: 16 * scale),
      bodyMedium: TextStyle(fontSize: 14 * scale),
      bodySmall: TextStyle(fontSize: 12 * scale),
      labelLarge: TextStyle(fontSize: 14 * scale),
      labelMedium: TextStyle(fontSize: 12 * scale),
      labelSmall: TextStyle(fontSize: 11 * scale),
    );
  }

  static IconButtonThemeData _buildIconButtonTheme(
    ColorScheme colorScheme,
    double baseFontSize,
  ) {
    return IconButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          AppSpacing.iconButtonPadding,
        ),
        iconSize: const WidgetStatePropertyAll<double>(AppControlSize.icon),
        shape: WidgetStateProperty.resolveWith<OutlinedBorder>(
          _iconButtonShape,
        ),
        minimumSize: WidgetStatePropertyAll<Size>(
          Size.square(AppControlSize.heightForFontSize(baseFontSize)),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          final color = colorScheme.onSurface;
          return states.contains(WidgetState.disabled)
              ? color.withValues(alpha: 0.38)
              : color;
        }),
      ),
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

    final buttonStyle = _buttonStyle(baseFontSize);
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: _primaryFontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      textTheme: _buildTextTheme(baseFontSize),
      iconTheme: IconThemeData(
        size: AppControlSize.icon,
        color: colorScheme.onSurface,
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: const AppBarTheme(
        toolbarHeight: AppControlSize.appBarHeight,
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowHeight: AppControlSize.height,
        dataRowMinHeight: AppControlSize.height,
        dataRowMaxHeight: double.infinity,
        horizontalMargin: AppSpacing.lg,
        columnSpacing: AppSpacing.xl,
      ),
      iconButtonTheme: _buildIconButtonTheme(colorScheme, baseFontSize),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      segmentedButtonTheme: SegmentedButtonThemeData(style: buttonStyle),
      chipTheme: const ChipThemeData(
        shape: _controlShape,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      dialogTheme: const DialogThemeData(shape: AppSurfaceShape.shape),
      popupMenuTheme: const PopupMenuThemeData(shape: _controlShape),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll<OutlinedBorder>(_controlShape),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(shape: _controlShape),
      navigationBarTheme: const NavigationBarThemeData(
        height: AppControlSize.navigationBarHeight,
        indicatorShape: _controlShape,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        minWidth: AppControlSize.navigationRailWidth,
        indicatorShape: _controlShape,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: _controlShape,
        sizeConstraints: BoxConstraints.tightFor(
          width: AppControlSize.fab,
          height: AppControlSize.fab,
        ),
        smallSizeConstraints: BoxConstraints.tightFor(
          width: AppControlSize.smallFab,
          height: AppControlSize.smallFab,
        ),
        largeSizeConstraints: BoxConstraints.tightFor(
          width: AppControlSize.largeFab,
          height: AppControlSize.largeFab,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: AppSurfaceShape.shape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: AppSpacing.fieldPadding,
        constraints: BoxConstraints(
          minHeight: AppControlSize.heightForFontSize(baseFontSize),
        ),
        border: const OutlineInputBorder(
          borderRadius: AppControlShape.borderRadius,
        ),
      ),
    );
    return theme.copyWith(listTileTheme: AppListStyle.themeFor(theme));
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

    final buttonStyle = _buttonStyle(baseFontSize);
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: _primaryFontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      textTheme: _buildTextTheme(baseFontSize),
      iconTheme: IconThemeData(
        size: AppControlSize.icon,
        color: colorScheme.onSurface,
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: const AppBarTheme(
        toolbarHeight: AppControlSize.appBarHeight,
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowHeight: AppControlSize.height,
        dataRowMinHeight: AppControlSize.height,
        dataRowMaxHeight: double.infinity,
        horizontalMargin: AppSpacing.lg,
        columnSpacing: AppSpacing.xl,
      ),
      iconButtonTheme: _buildIconButtonTheme(colorScheme, baseFontSize),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      segmentedButtonTheme: SegmentedButtonThemeData(style: buttonStyle),
      chipTheme: const ChipThemeData(
        shape: _controlShape,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      dialogTheme: const DialogThemeData(shape: AppSurfaceShape.shape),
      popupMenuTheme: const PopupMenuThemeData(shape: _controlShape),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll<OutlinedBorder>(_controlShape),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(shape: _controlShape),
      navigationBarTheme: const NavigationBarThemeData(
        height: AppControlSize.navigationBarHeight,
        indicatorShape: _controlShape,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        minWidth: AppControlSize.navigationRailWidth,
        indicatorShape: _controlShape,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: _controlShape,
        sizeConstraints: BoxConstraints.tightFor(
          width: AppControlSize.fab,
          height: AppControlSize.fab,
        ),
        smallSizeConstraints: BoxConstraints.tightFor(
          width: AppControlSize.smallFab,
          height: AppControlSize.smallFab,
        ),
        largeSizeConstraints: BoxConstraints.tightFor(
          width: AppControlSize.largeFab,
          height: AppControlSize.largeFab,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: AppSurfaceShape.shape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: AppSpacing.fieldPadding,
        constraints: BoxConstraints(
          minHeight: AppControlSize.heightForFontSize(baseFontSize),
        ),
        border: const OutlineInputBorder(
          borderRadius: AppControlShape.borderRadius,
        ),
      ),
    );
    return theme.copyWith(listTileTheme: AppListStyle.themeFor(theme));
  }
}

// MARK: - 通用元件

class _TitleWithIcon extends StatelessWidget {
  final IconData icon;
  final String text;
  final TextStyle? textStyle;

  const _TitleWithIcon({
    required this.icon,
    required this.text,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.iconTheme.color ?? theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: textStyle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Keep title-adjacent actions from crowding the heading when a Row
        // uses Spacer between this widget and its trailing controls.
        const SizedBox(width: 16),
      ],
    );
  }
}

class LargeTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const LargeTitle({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return _TitleWithIcon(
      icon: icon,
      text: text,
      textStyle: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class MediumTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const MediumTitle({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return _TitleWithIcon(
      icon: icon,
      text: text,
      textStyle: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class SmallTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const SmallTitle({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return _TitleWithIcon(
      icon: icon,
      text: text,
      textStyle: Theme.of(context).textTheme.titleSmall,
    );
  }
}

// MARK:開關項目元件
class SwitchWithTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;
  final EdgeInsetsGeometry padding;

  const SwitchWithTitle({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.padding = AppSpacing.formPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: subtitle != null && subtitle!.isNotEmpty
            ? Text(subtitle!, style: Theme.of(context).textTheme.labelTiny)
            : null,
        trailing: Switch(
          value: value,
          onChanged: (newValue) async {
            await onChanged(newValue);
          },
        ),
      ),
    );
  }
}

class SwitchWithIconTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;
  final EdgeInsetsGeometry padding;

  const SwitchWithIconTitle({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.padding = AppSpacing.formPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: subtitle != null && subtitle!.isNotEmpty
            ? Text(subtitle!, style: Theme.of(context).textTheme.labelTiny)
            : null,
        trailing: Switch(
          value: value,
          onChanged: (newValue) async {
            await onChanged(newValue);
          },
        ),
      ),
    );
  }
}

// 新增項目元件
class AddItemInput extends StatefulWidget {
  final bool useNeonStyle;
  final String title;
  final ValueChanged<String> onAdd;
  final TextEditingController? controller;
  final bool allowEmpty;
  final bool enabled;

  const AddItemInput({
    super.key,
    this.useNeonStyle = false,
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
          child: AppTextField(
            controller: _controller,
            enabled: widget.enabled,
            hintText: widget.enabled ? "新增${widget.title}" : widget.title,
            onSubmitted: (value) {
              if (widget.enabled &&
                  (widget.allowEmpty || value.trim().isNotEmpty)) {
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
            final bool canAdd =
                widget.enabled && (widget.allowEmpty || text.isNotEmpty);

            if (widget.useNeonStyle) {
              return NeonIconButton(
                onPressed: canAdd ? _handleAdd : null,
                icon: Icons.add_circle,
                label: "新增${widget.title}",
                accent: NeonAccent.green,
                statusLabel: canAdd
                    ? null
                    : widget.enabled
                    ? "請先輸入${widget.title}"
                    : "目前不可新增",
              );
            }
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

class DropdownOption<T> {
  final T value;
  final String label;
  final bool enabled;
  final Widget? child;

  const DropdownOption({
    required this.value,
    required this.label,
    this.enabled = true,
    this.child,
  });
}

class AppDropdownField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final bool isExpanded;
  final double menuMaxHeight;
  final TextStyle? textStyle;

  const AppDropdownField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelText,
    this.hintText,
    this.isExpanded = true,
    this.menuMaxHeight = AppControlSize.menuMaxHeight,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = appDropdownTextStyle(context, style: textStyle);

    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: isExpanded,
      isDense: true,
      menuMaxHeight: menuMaxHeight,
      itemHeight: appDropdownItemHeight(context),
      style: effectiveStyle,
      iconSize: AppControlSize.smallIcon,
      decoration: appDropdownFieldDecoration(
        context,
        textStyle: effectiveStyle,
        decoration: InputDecoration(labelText: labelText, hintText: hintText),
      ),
      items: options.map((option) {
        return DropdownMenuItem<T>(
          value: option.value,
          enabled: option.enabled,
          child:
              option.child ??
              Text(
                option.label,
                overflow: TextOverflow.ellipsis,
                style: effectiveStyle,
              ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// Chip 元件
class CardList extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool showHeader;
  final List<String> items;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int>? onConvert;
  final String? conversionKeyPrefix;

  const CardList({
    super.key,
    required this.title,
    required this.icon,
    this.showHeader = true,
    this.items = const [],
    required this.onAdd,
    required this.onRemove,
    this.onConvert,
    this.conversionKeyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // 現有項目
        if (items.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(item),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => onRemove(index),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer,
                  ),
                  if (onConvert != null)
                    IconButton(
                      key: ValueKey(
                        "${conversionKeyPrefix ?? title}-convert-$index",
                      ),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: AppControlSize.height,
                        minHeight: AppControlSize.height,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: "轉為正式物品關聯",
                      onPressed: () => onConvert!(index),
                      icon: const Icon(Icons.sync_alt, size: 18),
                    ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // 新增項目
        AddItemInput(title: title, onAdd: onAdd),
      ],
    );
  }
}

// MARK: - 可拖曳卡片節點

enum DropPosition { before, child, after }

enum NodeType { root, folder, item, leaf, unknown }

class DraggableCardNode<T extends Object> extends StatelessWidget {
  final T dragData;
  final String nodeId;
  final NodeType nodeType;

  // 狀態
  final bool isDragging;
  final bool isThisDragging;
  final bool isDragForbidden;
  final bool isSelected;

  // 內容與回調
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onClicked;

  // 拖放回調
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;
  final bool Function(T data, DropPosition pos)? onWillAccept;
  final void Function(T data, DropPosition pos)? onAccept;
  final double Function(DropPosition pos) getDropZoneSize;

  // 樣式
  final double indent;
  final Color? selectedColor;
  final Color? baseColor;

  const DraggableCardNode({
    super.key,
    required this.dragData,
    required this.nodeId,
    this.nodeType = NodeType.unknown,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onClicked,

    this.isDragging = false,
    this.isThisDragging = false,
    this.isDragForbidden = false,
    this.isSelected = false,

    this.onDragStarted,
    this.onDragEnd,
    this.onWillAccept,
    this.onAccept,
    required this.getDropZoneSize,

    this.indent = 0.0,
    this.selectedColor,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    // 卡片本體
    Widget cardContent = AppListCard(
      selected: isSelected,
      selectedColor: selectedColor,
      backgroundColor: baseColor,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onClicked,
    );

    // 拖曳包裝
    Widget draggable = LongPressDraggable<T>(
      data: dragData,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnd?.call(),
      onDraggableCanceled: (_, __) => onDragEnd?.call(),
      feedback: Material(
        elevation: 8,
        borderRadius: AppSurfaceShape.borderRadius,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: AppSurfaceShape.borderRadius,
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: title,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
      child: cardContent,
    );

    // 拖放區域堆疊
    Widget contentWithDropZones = Stack(
      children: [
        draggable,
        if (isDragging && !isThisDragging && !isDragForbidden)
          Positioned.fill(
            child: Column(
              children: [
                _buildDropZone(context, DropPosition.before),
                _buildDropZone(context, DropPosition.child),
                _buildDropZone(context, DropPosition.after),
              ],
            ),
          ),
      ],
    );

    // 縮排處理
    return Container(
      margin: EdgeInsetsDirectional.only(
        start: indent,
        bottom: AppListStyle.cardGap,
      ),
      child: contentWithDropZones,
    );
  }

  Widget _buildDropZone(BuildContext context, DropPosition pos) {
    double size = getDropZoneSize(pos);
    if (size <= 0) return const SizedBox.shrink();

    return Expanded(
      flex: (size * 100).toInt(),
      child: DragTarget<T>(
        onWillAcceptWithDetails: (details) =>
            onWillAccept?.call(details.data, pos) ?? true,
        onAcceptWithDetails: (details) {
          onAccept?.call(details.data, pos);
        },
        builder: (context, candidates, rejected) {
          if (candidates.isEmpty) {
            return Container(color: Colors.transparent);
          }

          Color color;
          IconData icon;
          if (pos == DropPosition.before) {
            color = Theme.of(context).colorScheme.tertiary;
            icon = Icons.arrow_upward;
          } else if (pos == DropPosition.after) {
            color = Theme.of(context).colorScheme.secondary;
            icon = Icons.arrow_downward;
          } else {
            color = Theme.of(context).colorScheme.primary;
            icon = Icons.subdirectory_arrow_right;
          }

          return Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              border: pos == DropPosition.child
                  ? Border.all(color: color, width: 2)
                  : Border(
                      top: pos == DropPosition.before
                          ? BorderSide(color: color, width: 3)
                          : BorderSide.none,
                      bottom: pos == DropPosition.after
                          ? BorderSide(color: color, width: 3)
                          : BorderSide.none,
                    ),
            ),
            child: Center(child: Icon(icon, color: color)),
          );
        },
      ),
    );
  }
}
