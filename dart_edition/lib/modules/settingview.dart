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
 * Competing products (≥3 overlapping modules or similar UI structure)
 * and repackaging without permission are prohibited.
 */

import "package:flutter/material.dart";
import "../bin/theme_manager.dart";
import "../bin/settings_manager.dart";

class SettingView extends StatefulWidget {
  final ThemeManager themeManager;
  final SettingsManager settingsManager;
  
  const SettingView({
    super.key,
    required this.themeManager,
    required this.settingsManager,
  });

  @override
  State<SettingView> createState() => _SettingViewState();
}

class _SettingViewState extends State<SettingView> {
  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題
            Row(
              children: [
                Icon(
                  Icons.settings,
                  size: widget.settingsManager.fontSize + 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  "設定",
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 主題設定卡片
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 主題設定標題
                    Row(
                      children: [
                        Icon(
                          Icons.palette,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "外觀設定",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 主題模式選擇
                    _buildThemeModeSetting(),
                    
                    const SizedBox(height: 24),

                    // 字體大小設定
                    _buildFontSizeSetting(),

                    const SizedBox(height: 24),
                    
                    // 主題顏色設定
                    _buildColorSetting(),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // 當前主題預覽
                    _buildThemePreview(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 其他設定卡片
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tune,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "其他設定",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSwitchSetting(
                      "退出時提示",
                      Icons.warning,
                      "關閉應用前提示儲存未儲存的變更",
                      widget.settingsManager.showExitWarning,
                      (value) async {
                        await widget.settingsManager.setShowExitWarning(value);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildPlaceholderSetting("自動儲存", Icons.save),
                    _buildPlaceholderSetting("自動備份", Icons.backup),
                    _buildPlaceholderSetting("語言設定", Icons.language),
                    _buildPlaceholderSetting("工具列項目編輯", Icons.bento_outlined),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 字體大小設定
  Widget _buildFontSizeSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Icon(
                Icons.text_fields, 
                size: widget.settingsManager.fontSize + 6, 
                color: Theme.of(context).colorScheme.primary
              ),
              const SizedBox(width: 12),
              Text(
                "字體大小調整",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              Text(
                "${widget.settingsManager.fontSize.toInt()} px",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: widget.settingsManager.fontSize,
          min: 12.0,
          max: 20.0,
          divisions: 8, // (20-12) = 8 steps, 1px per step
          label: "${widget.settingsManager.fontSize.toInt()} px",
          onChanged: (value) async {
            await widget.settingsManager.setFontSize(value);
            setState(() {});
          },
        ),
      ],
    );
  }

  // MARK: - 主題顏色設定
  Widget _buildColorSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            "主題顏色",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: ThemeManager.supportedColors.length,
          itemBuilder: (context, index) {
            final entry = ThemeManager.supportedColors.entries.elementAt(index);
            final isSelected = widget.themeManager.themeColor.value == entry.value.value;
            
            return Center(
              child: InkWell(
                onTap: () {
                  setState(() {
                    widget.themeManager.setThemeColor(entry.value);
                  });
                },
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: entry.value,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 2.5,
                          )
                        : Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 1,
                          ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: entry.value.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: entry.value.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          size: 20,
                        )
                      : entry.key == "Auto" 
                          ? Icon(
                              Icons.auto_awesome, 
                              color: entry.value.computeLuminance() > 0.5 ? Colors.black45 : Colors.white54,
                              size: 16
                            ) 
                          : null,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // MARK: - 主題模式設定
  Widget _buildThemeModeSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "主題模式",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<AppThemeMode>(
          segments: const [
            ButtonSegment<AppThemeMode>(
              value: AppThemeMode.light,
              label: Text("淺色"),
              icon: Icon(Icons.light_mode),
            ),
            ButtonSegment<AppThemeMode>(
              value: AppThemeMode.dark,
              label: Text("深色"),
              icon: Icon(Icons.dark_mode),
            ),
            ButtonSegment<AppThemeMode>(
              value: AppThemeMode.system,
              label: Text("自動"),
              icon: Icon(Icons.brightness_auto),
            ),
          ],
          selected: {widget.themeManager.themeMode},
          onSelectionChanged: (Set<AppThemeMode> newSelection) {
            setState(() {
              widget.themeManager.setThemeMode(newSelection.first);
            });
          },
        ),
      ],
    );
  }

  // MARK: - 主題預覽
  Widget _buildThemePreview() {
    final isDark = widget.themeManager.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // 當前模式指示
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                size: widget.settingsManager.fontSize + 6,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                "目前使用：${isDark ? "深色" : "淺色"}模式",
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // MARK: - 開關設定項目
  Widget _buildSwitchSetting(
    String title,
    IconData icon,
    String? subtitle,
    bool value,
    Future<void> Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
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

  // MARK: - 佔位元件
  Widget _buildPlaceholderSetting(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const Spacer(),
          Text(
            "即將推出",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
