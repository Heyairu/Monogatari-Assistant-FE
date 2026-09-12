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

import "package:flutter/material.dart";
import "../features/inline_annotations/alias_mention_updates.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../bin/file.dart" show AutoBackupDirectoryInfo;
import "../bin/ui_library.dart";
import "../bin/settings_manager.dart";
import "../presentation/providers/core_providers.dart";
import "../presentation/providers/global_state_providers.dart";
import "../presentation/providers/p2p_sync_providers.dart";
import "../services/android_background_execution.dart";

class SettingView extends ConsumerStatefulWidget {
  const SettingView({super.key});

  @override
  ConsumerState<SettingView> createState() => _SettingViewState();
}

class _SettingViewState extends ConsumerState<SettingView>
    with WidgetsBindingObserver {
  late Future<AutoBackupDirectoryInfo> _autoBackupDirectoryInfoFuture;
  bool _isBatteryOptimizationExempt = false;
  bool _isLoadingBackgroundPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoBackupDirectoryInfoFuture = _loadAutoBackupDirectoryInfo();
    _refreshBackgroundExecutionPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBackgroundExecutionPermission();
    }
  }

  Future<void> _refreshBackgroundExecutionPermission() async {
    if (!AndroidBackgroundExecution.isSupported) return;
    try {
      final isExempt =
          await AndroidBackgroundExecution.isBatteryOptimizationExempt();
      if (mounted) {
        setState(() => _isBatteryOptimizationExempt = isExempt);
      }
    } on PlatformException {
      // The action button will provide a user-visible error if the platform
      // cannot service the request.
    }
  }

  Future<void> _requestBackgroundExecutionPermission() async {
    if (_isLoadingBackgroundPermission) return;
    setState(() => _isLoadingBackgroundPermission = true);
    try {
      await AndroidBackgroundExecution.requestBatteryOptimizationExemption();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請在系統提示中允許不受電池最佳化限制。")));
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? "無法開啟背景執行權限。")));
    } finally {
      if (mounted) {
        setState(() => _isLoadingBackgroundPermission = false);
      }
    }
  }

  Future<AutoBackupDirectoryInfo> _loadAutoBackupDirectoryInfo() {
    return ref.read(projectFileUseCaseProvider).getAutoBackupDirectoryInfo();
  }

  void _refreshAutoBackupDirectoryInfo() {
    setState(() {
      _autoBackupDirectoryInfoFuture = _loadAutoBackupDirectoryInfo();
    });
  }

  ({AppThemeMode themeMode, Color themeColor}) get _themeViewState => ref.watch(
    themeStateProvider.select((state) {
      final theme = state.valueOrNull;
      return (
        themeMode: theme?.themeMode ?? AppThemeMode.system,
        themeColor: theme?.themeColor ?? Colors.lightBlue,
      );
    }),
  );

  ({
    bool showExitWarning,
    double fontSize,
    WordCountMode wordCountMode,
    bool autoSaveEnabled,
    int autoSaveIntervalMinutes,
    bool autoBackupEnabled,
    int autoBackupIntervalMinutes,
    int autoBackupMaxSizeMb,
    bool allowSingleDevicePairingConfirmation,
    bool allowPersistentP2pVerification,
    bool poppinEnabled,
  })
  get _settingsViewState => ref.watch(
    settingsStateProvider.select((state) {
      final settings = state.valueOrNull;
      return (
        showExitWarning: settings?.showExitWarning ?? true,
        fontSize: settings?.fontSize ?? 12.0,
        wordCountMode:
            settings?.wordCountMode ?? WordCountMode.wordsAndCharacters,
        autoSaveEnabled: settings?.autoSaveEnabled ?? false,
        autoSaveIntervalMinutes: settings?.autoSaveIntervalMinutes ?? 5,
        autoBackupEnabled: settings?.autoBackupEnabled ?? false,
        autoBackupIntervalMinutes: settings?.autoBackupIntervalMinutes ?? 5,
        autoBackupMaxSizeMb: settings?.autoBackupMaxSizeMb ?? 512,
        allowSingleDevicePairingConfirmation:
            settings?.allowSingleDevicePairingConfirmation ?? true,
        allowPersistentP2pVerification:
            settings?.allowPersistentP2pVerification ?? false,
        poppinEnabled: settings?.poppinEnabled ?? true,
      );
    }),
  );

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 標題
            const Align(
              alignment: Alignment.centerLeft,
              child: LargeTitle(icon: Icons.settings, text: "設定"),
            ),
            const SizedBox(height: 32),
            // 主題設定卡片
            AppSectionCard(
              padding: EdgeInsets.zero,
              useSectionLayout: false,
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 主題設定標題
                    const LargeTitle(icon: Icons.palette, text: "外觀設定"),
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
            AppSectionCard(
              padding: EdgeInsets.zero,
              useSectionLayout: false,
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LargeTitle(icon: Icons.tune, text: "其他設定"),
                    const SizedBox(height: 16),
                    SwitchWithIconTitle(
                      title: "退出時提示",
                      icon: Icons.warning,
                      subtitle: "關閉應用前提示儲存未儲存的變更",
                      value: _settingsViewState.showExitWarning,
                      onChanged: (value) async {
                        await ref
                            .read(settingsStateProvider.notifier)
                            .setShowExitWarning(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchWithIconTitle(
                      key: const Key("poppin-enabled-setting"),
                      title: "啟用 Poppin IntelliSense",
                      icon: Icons.auto_awesome_outlined,
                      subtitle: "輸入標記類型、/ 或 \\ 時顯示游標旁候選清單",
                      value: _settingsViewState.poppinEnabled,
                      onChanged: (value) async {
                        await ref
                            .read(settingsStateProvider.notifier)
                            .setPoppinEnabled(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildWordCountSetting(),
                    const SizedBox(height: 16),
                    SwitchWithIconTitle(
                      key: const Key("alias-mention-updates-setting"),
                      title: "修改別名時更新正文 Mention",
                      icon: Icons.sync,
                      subtitle: "更新同角色且顯示文字等於原別名的標記",
                      value:
                          ref
                              .watch(aliasMentionUpdatesEnabledProvider)
                              .valueOrNull ??
                          true,
                      onChanged: (value) => ref
                          .read(aliasMentionUpdatesEnabledProvider.notifier)
                          .setEnabled(value),
                    ),
                    const SizedBox(height: 16),
                    _buildAutoSaveSetting(),
                    const SizedBox(height: 16),
                    _buildAutoBackupSetting(),
                    const SizedBox(height: 8),
                    _buildAndroidBackgroundExecutionSetting(),
                    _buildPlaceholderSetting("語言設定", Icons.language),
                    _buildP2pSyncSetting(),
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

  Widget _buildP2pSyncSetting() {
    return Column(
      children: [
        SwitchWithIconTitle(
          key: const Key("p2p-single-device-confirmation-setting"),
          title: "允許單端確認配對碼",
          icon: Icons.phonelink_lock_outlined,
          subtitle: "僅在兩台裝置都開啟時生效；任一台確認後，另一台會驗證簽章並自動回簽",
          value: _settingsViewState.allowSingleDevicePairingConfirmation,
          onChanged: (value) async {
            await ref
                .read(settingsStateProvider.notifier)
                .setAllowSingleDevicePairingConfirmation(value);
            ref.read(p2pSyncProvider.notifier).handlePairingPreferenceChanged();
          },
        ),
        SwitchWithIconTitle(
          key: const Key("p2p-persistent-verification-setting"),
          title: "持久驗證（14 天）",
          icon: Icons.verified_user_outlined,
          subtitle: "僅在兩台裝置都開啟時生效；期限內可自動驗證，每次成功連線會重新續簽 14 天",
          value: _settingsViewState.allowPersistentP2pVerification,
          onChanged: (value) async {
            await ref
                .read(settingsStateProvider.notifier)
                .setAllowPersistentP2pVerification(value);
            ref.read(p2pSyncProvider.notifier).handlePairingPreferenceChanged();
          },
        ),
      ],
    );
  }

  Widget _buildAndroidBackgroundExecutionSetting() {
    if (!AndroidBackgroundExecution.isSupported) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          _isBatteryOptimizationExempt
              ? Icons.battery_full_outlined
              : Icons.battery_saver_outlined,
        ),
        title: const Text("允許背景常駐"),
        subtitle: Text(
          _isBatteryOptimizationExempt ? "已允許不受電池最佳化限制" : "讓已啟用的背景工作較不易被系統暫停",
        ),
        trailing: FilledButton(
          onPressed:
              _isBatteryOptimizationExempt || _isLoadingBackgroundPermission
              ? null
              : _requestBackgroundExecutionPermission,
          child: _isLoadingBackgroundPermission
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isBatteryOptimizationExempt ? "已允許" : "允許"),
        ),
      ),
    );
  }

  // MARK: - 字體大小設定
  Widget _buildFontSizeSetting() {
    return LabeledSlider(
      title: "字體大小調整",
      icon: Icons.text_fields,
      value: _settingsViewState.fontSize,
      min: 12,
      max: 20,
      divisions: 8,
      valueLabelBuilder: (value) => "${value.toInt()} px",
      onChanged: (value) async {
        await ref.read(settingsStateProvider.notifier).setFontSize(value);
      },
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
          itemCount: UILibrary.supportedColors.length,
          itemBuilder: (context, index) {
            final entry = UILibrary.supportedColors.entries.elementAt(index);
            final isSelected =
                _themeViewState.themeColor.toARGB32() == entry.value.toARGB32();

            return Center(
              child: InkWell(
                onTap: () => ref
                    .read(themeStateProvider.notifier)
                    .setThemeColor(entry.value),
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
                          color: entry.value.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          size: 20,
                        )
                      : entry.key == "Auto"
                      ? Icon(
                          Icons.auto_awesome,
                          color: entry.value.computeLuminance() > 0.5
                              ? Colors.black45
                              : Colors.white54,
                          size: 16,
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
        Text("主題模式", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        AppDropdownField<AppThemeMode>(
          value: _themeViewState.themeMode,
          labelText: "主題模式",
          options: const [
            DropdownOption<AppThemeMode>(
              value: AppThemeMode.light,
              label: "淺色",
            ),
            DropdownOption<AppThemeMode>(value: AppThemeMode.dark, label: "深色"),
            DropdownOption<AppThemeMode>(
              value: AppThemeMode.system,
              label: "自動",
            ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            await ref.read(themeStateProvider.notifier).setThemeMode(value);
          },
        ),
      ],
    );
  }

  // MARK: - 主題預覽
  Widget _buildThemePreview() {
    final colorScheme = Theme.of(context).colorScheme;
    final isSystemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark =
        _themeViewState.themeMode == AppThemeMode.dark ||
        (_themeViewState.themeMode == AppThemeMode.system && isSystemDark);
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
                size: _settingsViewState.fontSize + 6,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                "目前使用：${isDark ? "深色" : "淺色"}模式",
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // MARK: - 字數計算模式設定
  Widget _buildWordCountSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Icon(Icons.numbers, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("字數統計模式", style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    _settingsViewState.wordCountMode == WordCountMode.characters
                        ? "純字元數 (不建議)"
                        : "全形字元 + 半形單字",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AppDropdownField<WordCountMode>(
          value: _settingsViewState.wordCountMode,
          labelText: "字數統計模式",
          options: const [
            DropdownOption<WordCountMode>(
              value: WordCountMode.characters,
              label: "字元數 (不建議)",
            ),
            DropdownOption<WordCountMode>(
              value: WordCountMode.wordsAndCharacters,
              label: "混合模式",
            ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            await ref
                .read(settingsStateProvider.notifier)
                .setWordCountMode(value);
          },
        ),
      ],
    );
  }

  // MARK: - 自動儲存設定
  Widget _buildAutoSaveSetting() {
    final enabled = _settingsViewState.autoSaveEnabled;
    final interval = _settingsViewState.autoSaveIntervalMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchWithIconTitle(
          title: "自動儲存",
          icon: Icons.save,
          subtitle: "依排程儲存檔案（需要檔案存在）",
          value: enabled,
          onChanged: (value) async {
            await ref
                .read(settingsStateProvider.notifier)
                .setAutoSaveEnabled(value);
          },
        ),
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: IgnorePointer(
            ignoring: !enabled,
            child: LabeledSlider(
              title: "儲存間隔",
              icon: Icons.timer,
              value: interval.toDouble(),
              min: 0,
              max: 120,
              divisions: 24,
              layout: LabeledSliderLayout.inline,
              inlineTitleWidth: 96,
              valueLabelBuilder: (value) => "${value.round()} 分鐘",
              onChanged: (value) async {
                await ref
                    .read(settingsStateProvider.notifier)
                    .setAutoSaveIntervalMinutes(value.round());
              },
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - AutoBackup 設定
  Widget _buildAutoBackupSetting() {
    final enabled = _settingsViewState.autoBackupEnabled;
    final interval = _settingsViewState.autoBackupIntervalMinutes;
    final maxSizeMb = _settingsViewState.autoBackupMaxSizeMb;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchWithIconTitle(
          title: "自動備份",
          icon: Icons.backup,
          subtitle: "依排程建立專案備份，不覆蓋原檔案",
          value: enabled,
          onChanged: (value) async {
            await ref
                .read(settingsStateProvider.notifier)
                .setAutoBackupEnabled(value);
          },
        ),
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: IgnorePointer(
            ignoring: !enabled,
            child: LabeledSlider(
              title: "備份間隔",
              icon: Icons.timer,
              value: interval.toDouble(),
              min: 0,
              max: 120,
              divisions: 24,
              layout: LabeledSliderLayout.inline,
              inlineTitleWidth: 96,
              valueLabelBuilder: (value) => "${value.round()} 分鐘",
              onChanged: (value) async {
                await ref
                    .read(settingsStateProvider.notifier)
                    .setAutoBackupIntervalMinutes(value.round());
              },
            ),
          ),
        ),
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: IgnorePointer(
            ignoring: !enabled,
            child: LabeledSlider(
              title: "備份最高上限",
              icon: Icons.storage_outlined,
              value: maxSizeMb.clamp(16, 4096).toDouble(),
              min: 16,
              max: 4096,
              divisions: 255,
              layout: LabeledSliderLayout.stacked,
              valueLabelBuilder: (value) => "${value.round()} MB",
              onChanged: (value) async {
                await ref
                    .read(settingsStateProvider.notifier)
                    .setAutoBackupMaxSizeMb(value.round());
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        FutureBuilder<AutoBackupDirectoryInfo>(
          future: _autoBackupDirectoryInfoFuture,
          builder: (context, snapshot) {
            final info = snapshot.data;
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                info == null;

            if (isLoading) {
              return const Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (info == null || (info.isAndroid && !info.isConfigured)) {
              return TextButton.icon(
                onPressed: _selectAutoBackupDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text("選擇自動備份資料夾"),
              );
            }

            return Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _openAutoBackupDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text("開啟"),
                ),
                if (info.isAndroid)
                  TextButton.icon(
                    onPressed: _selectAutoBackupDirectory,
                    icon: const Icon(Icons.drive_folder_upload_outlined),
                    label: const Text("重新選擇"),
                  )
                else if (info.isDefault)
                  TextButton.icon(
                    onPressed: _selectAutoBackupDirectory,
                    icon: const Icon(Icons.drive_folder_upload_outlined),
                    label: const Text("選擇"),
                  )
                else
                  PopupMenuButton<String>(
                    tooltip: "AutoBackup 目錄選項",
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (value) async {
                      if (value == "select") {
                        await _selectAutoBackupDirectory();
                      } else if (value == "reset") {
                        await _resetAutoBackupDirectory();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: "select", child: Text("選擇")),
                      PopupMenuItem(value: "reset", child: Text("重設")),
                    ],
                  ),
                if (info.path.trim().isNotEmpty)
                  Text(
                    info.path,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  "${_formatBytes(info.totalBytes)} / $maxSizeMb MB ・ ${info.fileCount} 份",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  onPressed: info.fileCount == 0 ? null : _clearAutoBackups,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text("清理全部備份"),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  Future<void> _clearAutoBackups() async {
    try {
      final result = await ref
          .read(projectFileUseCaseProvider)
          .clearAutoBackups();
      if (!mounted) return;
      _refreshAutoBackupDirectoryInfo();
      AppFeedback.success(
        context,
        "已清理 ${result.deletedFiles} 份備份，釋放 ${_formatBytes(result.freedBytes)}。",
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.toString());
    }
  }

  Future<void> _openAutoBackupDirectory() async {
    try {
      final directoryPath = await ref
          .read(projectFileUseCaseProvider)
          .openAutoBackupDirectory();
      if (!mounted) {
        return;
      }
      AppFeedback.success(context, "已開啟 AutoBackup 目錄：$directoryPath");
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, e.toString());
    }
  }

  Future<void> _selectAutoBackupDirectory() async {
    try {
      final directoryPath = await ref
          .read(projectFileUseCaseProvider)
          .selectAutoBackupDirectory();
      if (!mounted) {
        return;
      }
      _refreshAutoBackupDirectoryInfo();
      AppFeedback.success(context, "AutoBackup 目錄已設定：$directoryPath");
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, e.toString());
    }
  }

  Future<void> _resetAutoBackupDirectory() async {
    try {
      final directoryPath = await ref
          .read(projectFileUseCaseProvider)
          .resetAutoBackupDirectory();
      if (!mounted) {
        return;
      }
      _refreshAutoBackupDirectoryInfo();
      AppFeedback.success(context, "AutoBackup 目錄已重設：$directoryPath");
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppFeedback.error(context, e.toString());
    }
  }

  // MARK: - 佔位元件
  Widget _buildPlaceholderSetting(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(title, style: Theme.of(context).textTheme.labelMedium),
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
