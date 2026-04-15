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

import "dart:convert";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/services.dart";
import "package:url_launcher/url_launcher.dart";
import "../bin/ui_library.dart";
import "../bin/settings_manager.dart";
import "../presentation/providers/global_state_providers.dart";

class WelcomeView extends ConsumerStatefulWidget {
  const WelcomeView({
    super.key,
    this.onNewProject,
    this.onOpenProject,
    this.recentProjects,
    this.onOpenRecentProject,
    this.onDeleteRecentProject,
  });

  final Future<void> Function()? onNewProject;
  final Future<void> Function()? onOpenProject;
  final List<RecentProjectEntry>? recentProjects;
  final Future<void> Function(RecentProjectEntry entry)? onOpenRecentProject;
  final Future<void> Function(RecentProjectEntry entry)? onDeleteRecentProject;

  @override
  ConsumerState<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends ConsumerState<WelcomeView> {
  static const String _didYouKnowAssetPath = "assets/jsons/didyouknow.json";
  static const String _eastAsiaNameAssetPath =
      "assets/jsons/name_eastAsia.json";
  static const _DidYouKnowData _fallbackDidYouKnowData = _DidYouKnowData(
    content: "中國最偉大、最永久的藝術，就是男人扮女人",
    source: "—— 魯迅（1881-1936）",
  );
  static final Uri _projectRepoUri = Uri.parse(
    "https://github.com/heyairu/Monogatari-Assistant-FE",
  );
  static final Uri _KadoURL = Uri.parse(
    "https://www.kadokado.com.tw/user/167702",
  );
  static final Uri _KoFiURL = Uri.parse("https://ko-fi.com/heyairu");
  static final Random _random = Random();

  late Future<_DidYouKnowData> _didYouKnowFuture;
  Map<String, dynamic>? _eastAsiaNameData;
  bool _isGeneratingNames = false;
  String _selectedLanguage = "JP";
  String _selectedGender = "female";
  int _generateCount = 5;
  List<String> _generatedNames = const [];

  @override
  void initState() {
    super.initState();
    _didYouKnowFuture = _loadDidYouKnowData();
  }

  void _reloadDidYouKnow() {
    setState(() {
      _didYouKnowFuture = _loadDidYouKnowData();
    });
  }

  Future<_DidYouKnowData> _loadDidYouKnowData() async {
    try {
      final String rawJson = await rootBundle.loadString(_didYouKnowAssetPath);
      if (rawJson.trim().isEmpty) {
        return _fallbackDidYouKnowData;
      }

      final dynamic decoded = jsonDecode(rawJson);
      final List<_DidYouKnowData> candidates = [];

      void collectFromList(List<dynamic> list) {
        for (final dynamic item in list) {
          if (item is Map<String, dynamic>) {
            final _DidYouKnowData? parsed = _parseDidYouKnowMap(item);
            if (parsed != null) {
              candidates.add(parsed);
            }
          }
        }
      }

      if (decoded is Map<String, dynamic>) {
        final _DidYouKnowData? fromDirectMap = _parseDidYouKnowMap(decoded);
        if (fromDirectMap != null) {
          candidates.add(fromDirectMap);
        }

        final dynamic items = decoded["items"];
        if (items is List) {
          collectFromList(items);
        }
      }

      if (decoded is List) {
        collectFromList(decoded);
      }

      if (candidates.isNotEmpty) {
        final int randomIndex = _random.nextInt(candidates.length);
        return candidates[randomIndex];
      }
    } catch (error) {
      debugPrint("Failed to load Did You Know JSON: $error");
    }

    return _fallbackDidYouKnowData;
  }

  _DidYouKnowData? _parseDidYouKnowMap(Map<String, dynamic> map) {
    final dynamic content = map["content"];
    final dynamic source = map["source"];
    if (content is String &&
        content.trim().isNotEmpty &&
        source is String &&
        source.trim().isNotEmpty) {
      return _DidYouKnowData(content: content, source: source);
    }
    return null;
  }

  Future<void> _ensureEastAsiaNameDataLoaded() async {
    if (_eastAsiaNameData != null) {
      return;
    }

    final String rawJson = await rootBundle.loadString(_eastAsiaNameAssetPath);
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException("Invalid East Asia name JSON format");
    }
    _eastAsiaNameData = decoded;
  }

  List<String> _extractSurnamePool(String languageCode) {
    if (_eastAsiaNameData == null) {
      return const [];
    }

    if (languageCode == "ZH" || languageCode == "KR") {
      final String key = languageCode == "ZH" ? "Surname_ZH" : "Surname_KR";
      final dynamic raw = _eastAsiaNameData![key];
      if (raw is List) {
        return raw.whereType<String>().where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    if (languageCode == "JP") {
      final dynamic raw = _eastAsiaNameData!["Surname_JP"];
      if (raw is! List || raw.isEmpty || raw.first is! Map<String, dynamic>) {
        return const [];
      }

      final Map<String, dynamic> grouped = raw.first as Map<String, dynamic>;
      final List<String> flattened = [];
      for (final dynamic value in grouped.values) {
        if (value is List) {
          flattened.addAll(
            value.whereType<String>().where((s) => s.isNotEmpty).toList(),
          );
        }
      }
      return flattened;
    }

    return const [];
  }

  List<String> _extractGivenNamePool(String languageCode, String genderCode) {
    if (_eastAsiaNameData == null) {
      return const [];
    }

    List<String> collectPoolByRootKey(String rootKey) {
      final dynamic raw = _eastAsiaNameData![rootKey];
      if (raw is! List || raw.isEmpty || raw.first is! Map<String, dynamic>) {
        return const [];
      }

      final Map<String, dynamic> grouped = raw.first as Map<String, dynamic>;
      final List<String> pool = [];

      for (final dynamic value in grouped.values) {
        if (value is! List ||
            value.isEmpty ||
            value.first is! Map<String, dynamic>) {
          continue;
        }

        final Map<String, dynamic> namesByLanguage =
            value.first as Map<String, dynamic>;
        for (final MapEntry<String, dynamic> entry in namesByLanguage.entries) {
          final dynamic languages = entry.value;
          if (languages is List &&
              languages.whereType<String>().contains(languageCode)) {
            pool.add(entry.key);
          }
        }
      }

      return pool;
    }

    if (genderCode == "male") {
      return collectPoolByRootKey("Name_Man");
    }

    if (genderCode == "all" || genderCode == "neutral") {
      return <String>{
        ...collectPoolByRootKey("Name_Lady"),
        ...collectPoolByRootKey("Name_Man"),
      }.toList();
    }

    return collectPoolByRootKey("Name_Lady");
  }

  Future<void> _generateNames() async {
    setState(() {
      _isGeneratingNames = true;
    });

    try {
      await _ensureEastAsiaNameDataLoaded();

      final List<String> surnamePool = _extractSurnamePool(_selectedLanguage);
      final List<String> givenNamePool = _extractGivenNamePool(
        _selectedLanguage,
        _selectedGender,
      );
      if (surnamePool.isEmpty || givenNamePool.isEmpty) {
        throw const FormatException("Name data pool is empty");
      }

      final List<String> results = List<String>.generate(_generateCount, (_) {
        final String surname = surnamePool[_random.nextInt(surnamePool.length)];
        final String given =
            givenNamePool[_random.nextInt(givenNamePool.length)];
        return "$surname$given";
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _generatedNames = results;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("載入姓名資料失敗，請稍後再試。")));
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isGeneratingNames = false;
      });
    }
  }

  Future<void> _copyGeneratedNames() async {
    if (_generatedNames.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: _generatedNames.join("\n")));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("已複製姓名結果")));
  }

  Future<void> _handleNewProject() async {
    final onNewProject = widget.onNewProject;
    if (onNewProject == null) {
      _showMessage("目前尚未連接新建專案功能");
      return;
    }

    await onNewProject();
  }

  Future<void> _handleOpenProject() async {
    final onOpenProject = widget.onOpenProject;
    if (onOpenProject == null) {
      _showMessage("目前尚未連接開啟檔案功能");
      return;
    }

    await onOpenProject();
  }

  Future<void> _handleOpenRecentProject(RecentProjectEntry entry) async {
    final onOpenRecentProject = widget.onOpenRecentProject;
    if (onOpenRecentProject == null) {
      _showMessage("目前尚未連接最近檔案功能");
      return;
    }

    await onOpenRecentProject(entry);
  }

  Future<void> _handleDeleteRecentProject(RecentProjectEntry entry) async {
    final onDeleteRecentProject = widget.onDeleteRecentProject;
    if (onDeleteRecentProject == null) {
      _showMessage("目前尚未連接刪除最近檔案功能");
      return;
    }

    await onDeleteRecentProject(entry);
  }

  Future<void> _openExternalLink(Uri uri) async {
    try {
      final bool didLaunch = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!didLaunch) {
        throw const FormatException("Unable to launch external link");
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      if (!mounted) {
        return;
      }
      _showMessage("無法直接開啟連結，已複製到剪貼簿");
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    final List<RecentProjectEntry> recentProjects =
        widget.recentProjects ??
        ref.watch(settingsStateProvider).valueOrNull?.recentProjects ??
        const [];

    final Set<String> supportedGenderValues = <String>{
      "all",
      "male",
      "neutral",
      "female",
    };
    final String effectiveGenderValue =
        supportedGenderValues.contains(_selectedGender)
        ? _selectedGender
        : "female";

    final ButtonStyle TextButtonStyle =
        (Theme.of(context).textButtonTheme.style ?? const ButtonStyle())
            .copyWith(
              textStyle: WidgetStatePropertyAll<TextStyle?>(
                Theme.of(context).textTheme.labelSmall,
              ),
            );
    final TextStyle? dropdownTextStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 標題
            Text(
              "Welcome to",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              "ものがたり·アシスタント",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "—— For Refined Editing. Powered by Heyairu.",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Start
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SmallTitle(
                      icon: Icons.format_list_bulleted,
                      text: "Start",
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      style: TextButtonStyle,
                      onPressed: _handleNewProject,
                      child: Row(
                        children: const [
                          Icon(Icons.create_outlined, size: 18),
                          SizedBox(width: 4),
                          Text("New Project"),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButtonStyle,
                      onPressed: _handleOpenProject,
                      child: Row(
                        children: const [
                          Icon(Icons.folder_open, size: 18),
                          SizedBox(width: 4),
                          Text("Open File"),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButtonStyle,
                      onPressed: () => _openExternalLink(_projectRepoUri),
                      child: Row(
                        children: const [
                          Icon(Icons.code, size: 18),
                          SizedBox(width: 4),
                          Text("Open GitHub Repo for This Project"),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButtonStyle,
                      onPressed: () => _openExternalLink(_KadoURL),
                      child: Row(
                        children: const [
                          Icon(Icons.person_pin, size: 18),
                          SizedBox(width: 4),
                          Text("Heyairu's Profile on KadoKado"),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButtonStyle,
                      onPressed: () => _openExternalLink(_KoFiURL),
                      child: Row(
                        children: const [
                          Icon(Icons.coffee, size: 18),
                          SizedBox(width: 4),
                          Text("Heyairu's Ko-fi"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Did you know?
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _reloadDidYouKnow,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmallTitle(
                        icon: Icons.info_outline,
                        text: "Did you know?",
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<_DidYouKnowData>(
                        future: _didYouKnowFuture,
                        builder: (context, snapshot) {
                          final _DidYouKnowData didYouKnowData =
                              snapshot.data ?? _fallbackDidYouKnowData;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                didYouKnowData.content, //Content
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                "——" + didYouKnowData.source, //Source
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Recent Files
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SmallTitle(icon: Icons.folder, text: "Recent"),
                    const SizedBox(height: 12),
                    if (recentProjects.isEmpty)
                      Text(
                        "尚無最近開啟檔案",
                        style: Theme.of(context).textTheme.labelMedium,
                      )
                    else
                      ...recentProjects.take(5).map((entry) {
                        final subtitle = entry.filePath ?? entry.uri ?? "無可用路徑";
                        return Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                style: TextButtonStyle,
                                onPressed: () =>
                                    _handleOpenRecentProject(entry),
                                child: Row(
                                  children: [
                                    const Icon(Icons.history, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: "從最近清單移除",
                              onPressed: () =>
                                  _handleDeleteRecentProject(entry),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            ),
            // Features
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SmallTitle(icon: Icons.person_outline, text: "姓名產生器"),
                    const SizedBox(height: 16),
                    // Col 1: language, gender, count, generate button.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "語言",
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _selectedLanguage,
                              isExpanded: true,
                              style: dropdownTextStyle,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem<String>(
                                  value: "JP",
                                  child: Text("日式"),
                                ),
                                DropdownMenuItem<String>(
                                  value: "ZH",
                                  child: Text("中式"),
                                ),
                                DropdownMenuItem<String>(
                                  value: "KR",
                                  child: Text("韓式"),
                                ),
                              ],
                              onChanged: (String? value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedLanguage = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "性別",
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: effectiveGenderValue,
                              isExpanded: true,
                              style: dropdownTextStyle,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem<String>(
                                  value: "all",
                                  enabled: false,
                                  child: Text("全部（目前不可用）"),
                                ),
                                DropdownMenuItem<String>(
                                  value: "male",
                                  child: Text("男性"),
                                ),
                                DropdownMenuItem<String>(
                                  value: "neutral",
                                  enabled: false,
                                  child: Text("中性（目前不可用）"),
                                ),
                                DropdownMenuItem<String>(
                                  value: "female",
                                  child: Text("女性"),
                                ),
                              ],
                              onChanged: (String? value) {
                                if (value == null ||
                                    value == "all" ||
                                    value == "neutral") {
                                  return;
                                }
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "生成數",
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              value: _generateCount,
                              isExpanded: true,
                              style: dropdownTextStyle,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: const [1, 3, 5, 10, 20]
                                  .map(
                                    (int value) => DropdownMenuItem<int>(
                                      value: value,
                                      child: Text("$value"),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (int? value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _generateCount = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          style: TextButtonStyle,
                          onPressed: _isGeneratingNames ? null : _generateNames,
                          child: Row(
                            children: [
                              MediumTitle(icon: Icons.east, text: "生成"),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Col 2: selectable and copyable generated results.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "結果",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                                IconButton(
                                  tooltip: "複製結果",
                                  onPressed: _generatedNames.isEmpty
                                      ? null
                                      : _copyGeneratedNames,
                                  icon: const Icon(Icons.copy_all_outlined),
                                ),
                              ],
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(minHeight: 120),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: SelectionArea(
                                child: Text(
                                  _generatedNames.isEmpty
                                      ? "按下「生成」來產生姓名"
                                      : _generatedNames.join("\n"),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Sync
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SmallTitle(
                      icon: Icons.sync_alt_outlined,
                      text: "內容同步",
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DidYouKnowData {
  const _DidYouKnowData({required this.content, required this.source});

  final String content;
  final String source;
}
