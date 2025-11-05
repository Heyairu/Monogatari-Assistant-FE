import "package:flutter/material.dart";
import "../bin/theme_manager.dart";

class SettingView extends StatefulWidget {
  final ThemeManager themeManager;
  
  const SettingView({super.key, required this.themeManager});

  @override
  State<SettingView> createState() => _SettingViewState();
}

class _SettingViewState extends State<SettingView> {
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
                  size: 32,
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
            
            // 其他設定卡片（佔位）
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
                    _buildPlaceholderSetting("自動儲存", Icons.save),
                    _buildPlaceholderSetting("自動備份", Icons.backup),
                    _buildPlaceholderSetting("退出時提示", Icons.warning),
                    _buildPlaceholderSetting("語言設定", Icons.language),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 主題模式設定
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

  /// 主題預覽
  Widget _buildThemePreview() {
    final isDark = widget.themeManager.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "當前主題預覽",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // 色彩預覽
        Row(
          children: [
            Expanded(
              child: _buildColorSwatch(
                "主色",
                colorScheme.primary,
                colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildColorSwatch(
                "次要色",
                colorScheme.secondary,
                colorScheme.onSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildColorSwatch(
                "背景",
                colorScheme.surface,
                colorScheme.onSurface,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
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
                size: 20,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                "目前使用：${isDark ? '深色' : '淺色'}模式",
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

  /// 顏色色塊
  Widget _buildColorSwatch(String label, Color color, Color onColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.palette, color: onColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: onColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 佔位設定項目
  Widget _buildPlaceholderSetting(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
