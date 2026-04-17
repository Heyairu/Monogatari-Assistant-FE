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
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "package:xml/xml.dart" as xml;
import "../bin/ui_library.dart";
import "package:logging/logging.dart";
import "../bin/settings_manager.dart";
import "../models/base_info_data.dart";
import "../presentation/providers/global_state_providers.dart";
import "../presentation/providers/project_state_providers.dart";

export "../models/base_info_data.dart";

final _log = Logger("BaseInfoView");

// MARK: - XML Codec (compatible with the Qt format)

class BaseInfoCodec {
  static BaseInfoData createSaveSnapshot({
    required BaseInfoData data,
    required String contentText,
    bool updateLatestSave = true,
    WordCountMode wordCountMode = WordCountMode.characters,
  }) {
    return data
        .copyWith(
          latestSave: updateLatestSave ? DateTime.now() : data.latestSave,
        )
        .withRecalculatedNowWords(contentText, mode: wordCountMode);
  }

  static void _writeTextElement(
    xml.XmlBuilder builder,
    String name,
    String value,
  ) {
    builder.element(
      name,
      nest: () {
        builder.text(_encodeNewlines(value));
      },
    );
  }

  static String _readElementText(xml.XmlElement? element) {
    if (element == null) return "";
    if (element.children.isEmpty) {
      return _decodeNewlines(element.innerText);
    }
    final cdataBuffer = StringBuffer();
    for (final node in element.children) {
      if (node is xml.XmlCDATA) {
        cdataBuffer.write(node.text);
      }
    }
    final cdataText = cdataBuffer.toString();
    if (cdataText.isNotEmpty) {
      return _decodeNewlines(cdataText);
    }
    final buffer = StringBuffer();
    for (final node in element.children) {
      if (node is xml.XmlText || node is xml.XmlCDATA) {
        buffer.write(node.text);
      }
    }
    final text = buffer.toString();
    return _decodeNewlines(text.isNotEmpty ? text : element.innerText);
  }

  static String _encodeNewlines(String value) {
    if (value.isEmpty) return value;
    final normalized = value.replaceAll("\r\n", "\n").replaceAll("\r", "\n");
    final buffer = StringBuffer();
    for (final codeUnit in normalized.codeUnits) {
      switch (codeUnit) {
        case 10: // \n
          buffer.write("&#10;");
          break;
        case 35: // #
          buffer.write("&#35;");
          break;
        case 59: // ;
          buffer.write("&#59;");
          break;
        default:
          buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static String _decodeNewlines(String value) {
    return value
        .replaceAll("&#13;", "")
        .replaceAll("&#10;", "\n")
        .replaceAll("&#35;", "#")
        .replaceAll("&#59;", ";");
  }

  /// 序列化成與 Qt SaveFile() 兼容的 <Type> 片段
  static String? saveXML({
    required BaseInfoData data,
    required int totalWords,
    required String contentText,
    bool updateLatestSave = true,
    WordCountMode wordCountMode = WordCountMode.characters,
    BaseInfoData? snapshot,
  }) {
    final resolved =
        snapshot ??
        createSaveSnapshot(
          data: data,
          contentText: contentText,
          updateLatestSave: updateLatestSave,
          wordCountMode: wordCountMode,
        );
    if (resolved.isEffectivelyEmpty) return null;

    final isoSave = resolved.latestSave?.toIso8601String() ?? "";

    final builder = xml.XmlBuilder();
    builder.element(
      "Type",
      nest: () {
        builder.element("Name", nest: "BaseInfo");
        builder.element(
          "General",
          nest: () {
            _writeTextElement(builder, "BookName", resolved.bookName);
            _writeTextElement(builder, "Author", resolved.author);
            _writeTextElement(builder, "Purpose", resolved.purpose);
            _writeTextElement(builder, "ToRecap", resolved.toRecap);
            _writeTextElement(builder, "StoryType", resolved.storyType);
            _writeTextElement(builder, "Intro", resolved.intro);
            if (isoSave.isNotEmpty) {
              builder.element("LatestSave", nest: isoSave);
            }
          },
        );
        builder.element(
          "Tags",
          nest: () {
            for (String tag in resolved.tags) {
              final trimmed = tag.trim();
              if (trimmed.isNotEmpty) {
                _writeTextElement(builder, "Tag", trimmed);
              }
            }
          },
        );
        builder.element(
          "Stats",
          nest: () {
            // Stats can be added here if needed in the future
          },
        );
      },
    );

    // Indent formatting, consistent with previous behavior
    return builder.buildDocument().toXmlString(pretty: true, indent: "  ");
  }

  /// 自 <Type> 區塊解析（需 <Name>BaseInfo</Name>）
  static BaseInfoData? loadXML(String content) {
    try {
      final document = xml.XmlDocument.parse(content);

      // Find the <Type> root element
      final typeElement = document.findAllElements("Type").firstOrNull;
      if (typeElement == null) return null;

      // Check for <Name>BaseInfo</Name>
      final nameElement = typeElement.findAllElements("Name").firstOrNull;
      if (nameElement?.innerText != "BaseInfo") return null;

      DateTime? latestSave;
      int nowWords = 0;

      // <General> parsing
      final general = typeElement.findAllElements("General").firstOrNull;
      var bookName = "";
      var author = "";
      var purpose = "";
      var toRecap = "";
      var storyType = "";
      var intro = "";
      if (general != null) {
        bookName = _readElementText(
          general.findAllElements("BookName").firstOrNull,
        );
        author = _readElementText(
          general.findAllElements("Author").firstOrNull,
        );
        purpose = _readElementText(
          general.findAllElements("Purpose").firstOrNull,
        );
        toRecap = _readElementText(
          general.findAllElements("ToRecap").firstOrNull,
        );
        storyType = _readElementText(
          general.findAllElements("StoryType").firstOrNull,
        );
        intro = _readElementText(general.findAllElements("Intro").firstOrNull);

        final latestSaveStr = general
            .findAllElements("LatestSave")
            .firstOrNull
            ?.innerText;
        if (latestSaveStr != null && latestSaveStr.isNotEmpty) {
          try {
            latestSave = DateTime.parse(latestSaveStr);
          } catch (e) {
            // Keep null if parsing fails
          }
        }
      }

      // <Tags> parsing
      final tags = <String>[];
      final tagsElement = typeElement.findAllElements("Tags").firstOrNull;
      if (tagsElement != null) {
        for (final tagNode in tagsElement.findAllElements("Tag")) {
          final tagText = _readElementText(tagNode).trim();
          if (tagText.isNotEmpty) {
            tags.add(tagText);
          }
        }
      }

      // <Stats> parsing (e.g. NowWords) - if it exists in the XML
      final statsElement = typeElement.findAllElements("Stats").firstOrNull;
      if (statsElement != null) {
        final nowWordsStr = statsElement
            .findAllElements("NowWords")
            .firstOrNull
            ?.innerText;
        if (nowWordsStr != null) {
          nowWords = int.tryParse(nowWordsStr) ?? 0;
        }
      }

      return BaseInfoData(
        bookName: bookName,
        author: author,
        purpose: purpose,
        toRecap: toRecap,
        storyType: storyType,
        intro: intro,
        tags: tags,
        latestSave: latestSave,
        nowWords: nowWords,
      );
    } catch (e) {
      _log.severe("Error parsing BaseInfo XML: $e");
      return null;
    }
  }
}

// MARK: - View

class BaseInfoView extends ConsumerStatefulWidget {
  final ValueChanged<BaseInfoData>? onDataChanged;

  const BaseInfoView({super.key, this.onDataChanged});

  @override
  ConsumerState<BaseInfoView> createState() => _BaseInfoViewState();
}

class _BaseInfoViewState extends ConsumerState<BaseInfoView> {
  late BaseInfoData _data;
  bool _isUpdating = false;
  final DateFormat _dateFormatter = DateFormat("yyyy.MM.dd HH:mm:ss");
  ProviderSubscription<BaseInfoData>? _baseInfoSubscription;
  ProviderSubscription<String>? _contentSubscription;
  ProviderSubscription<AsyncValue<AppSettingsStateData>>? _settingsSubscription;

  // 為每個文字欄位創建專用的 TextEditingController
  late final TextEditingController _bookNameController;
  late final TextEditingController _authorController;
  late final TextEditingController _purposeController;
  late final TextEditingController _toRecapController;
  late final TextEditingController _storyTypeController;
  late final TextEditingController _introController;

  @override
  void initState() {
    super.initState();
    _data = ref.read(baseInfoDataProvider);
    _syncNowWords(commitToProvider: false);

    // 初始化各個文字欄位的 controller
    _bookNameController = TextEditingController(text: _data.bookName);
    _authorController = TextEditingController(text: _data.author);
    _purposeController = TextEditingController(text: _data.purpose);
    _toRecapController = TextEditingController(text: _data.toRecap);
    _storyTypeController = TextEditingController(text: _data.storyType);
    _introController = TextEditingController(text: _data.intro);

    // 添加監聽器
    _bookNameController.addListener(() {
      if (_isUpdating) return;
      _applyChange((data) => data.copyWith(bookName: _bookNameController.text));
    });

    _authorController.addListener(() {
      if (_isUpdating) return;
      _applyChange((data) => data.copyWith(author: _authorController.text));
    });

    _purposeController.addListener(() {
      if (_isUpdating) return;
      _applyChange((data) => data.copyWith(purpose: _purposeController.text));
    });

    _toRecapController.addListener(() {
      if (_isUpdating) return;
      _applyChange((data) => data.copyWith(toRecap: _toRecapController.text));
    });

    _storyTypeController.addListener(() {
      if (_isUpdating) return;
      _applyChange(
        (data) => data.copyWith(storyType: _storyTypeController.text),
      );
    });

    _introController.addListener(() {
      if (_isUpdating) return;
      _applyChange((data) => data.copyWith(intro: _introController.text));
    });

    _baseInfoSubscription = ref.listenManual<BaseInfoData>(
      baseInfoDataProvider,
      (previous, next) {
        if (_isUpdating || previous == next) {
          return;
        }
        _syncFromProvider(next);
      },
    );

    _contentSubscription = ref.listenManual<String>(editorContentProvider, (
      previous,
      next,
    ) {
      if (previous == next) {
        return;
      }
      _syncNowWords();
    });

    _settingsSubscription = ref.listenManual<AsyncValue<AppSettingsStateData>>(
      settingsStateProvider,
      (previous, next) {
        final previousMode = previous?.valueOrNull?.wordCountMode;
        final nextMode = next.valueOrNull?.wordCountMode;
        if (previousMode == nextMode) {
          return;
        }
        _syncNowWords();
      },
    );
  }

  @override
  void dispose() {
    _baseInfoSubscription?.close();
    _contentSubscription?.close();
    _settingsSubscription?.close();
    _bookNameController.dispose();
    _authorController.dispose();
    _purposeController.dispose();
    _toRecapController.dispose();
    _storyTypeController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _notifyDataChanged({bool notifyParent = true}) {
    final snapshot = _data.copyWith();
    ref.read(baseInfoDataProvider.notifier).setBaseInfoData(snapshot);
    if (notifyParent) {
      widget.onDataChanged?.call(snapshot);
    }
  }

  void _syncFromProvider(BaseInfoData source) {
    final nextData = source.copyWith();
    setState(() {
      _isUpdating = true;
      _data = nextData;
      _syncControllerText(_bookNameController, _data.bookName);
      _syncControllerText(_authorController, _data.author);
      _syncControllerText(_purposeController, _data.purpose);
      _syncControllerText(_toRecapController, _data.toRecap);
      _syncControllerText(_storyTypeController, _data.storyType);
      _syncControllerText(_introController, _data.intro);
      _isUpdating = false;
    });
  }

  void _syncControllerText(TextEditingController controller, String nextText) {
    if (controller.text == nextText) {
      return;
    }

    final previousSelection = controller.selection;
    final hasValidSelection =
        previousSelection.baseOffset >= 0 &&
        previousSelection.extentOffset >= 0;

    if (!hasValidSelection) {
      controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
      return;
    }

    final int baseOffset = previousSelection.baseOffset > nextText.length
        ? nextText.length
        : previousSelection.baseOffset;
    final int extentOffset = previousSelection.extentOffset > nextText.length
        ? nextText.length
        : previousSelection.extentOffset;

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      ),
    );
  }

  void _syncNowWords({bool commitToProvider = true}) {
    final settingsState = ref.read(settingsStateProvider).valueOrNull;
    final contentText = ref.read(editorContentProvider);
    final wordCountMode =
        settingsState?.wordCountMode ?? WordCountMode.wordsAndCharacters;

    setState(() {
      _data = _data.withRecalculatedNowWords(contentText, mode: wordCountMode);
    });
    if (commitToProvider) {
      _notifyDataChanged(notifyParent: false);
    }
  }

  void _applyChange(BaseInfoData Function(BaseInfoData data) update) {
    setState(() {
      _data = update(_data);
    });
    _notifyDataChanged();
  }

  void _addTag(String tagText) {
    tagText = tagText.trim();
    if (tagText.isEmpty || _data.tags.contains(tagText)) {
      return;
    }

    setState(() {
      _data = _data.copyWith(tags: [..._data.tags, tagText]);
    });
    _notifyDataChanged();
  }

  void _removeTag(int index) {
    final nextTags = [..._data.tags]..removeAt(index);
    setState(() {
      _data = _data.copyWith(tags: nextTags);
    });
    _notifyDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(baseInfoDataProvider);
    ref.watch(editorContentProvider);
    ref.watch(settingsStateProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 標題
            const Align(
              alignment: Alignment.centerLeft,
              child: LargeTitle(icon: Icons.info_outline, text: "基本資訊"),
            ),
            const SizedBox(height: 32),
            // 表單卡片
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 書名
                    _buildTextFieldSection(
                      label: "書名",
                      hint: "輸入書名",
                      controller: _bookNameController,
                      icon: Icons.book,
                    ),

                    const SizedBox(height: 20),

                    // 作者
                    _buildTextFieldSection(
                      label: "作者",
                      hint: "輸入作者名",
                      controller: _authorController,
                      icon: Icons.person,
                    ),

                    const SizedBox(height: 20),

                    // 故事主旨
                    _buildTextFieldSection(
                      label: "主旨",
                      hint: "輸入故事主旨",
                      controller: _purposeController,
                      icon: Icons.lightbulb_outline,
                    ),

                    const SizedBox(height: 20),

                    // 一句話簡介
                    _buildTextFieldSection(
                      label: "一句話簡介",
                      hint: "輸入一句話簡介",
                      controller: _toRecapController,
                      icon: Icons.summarize,
                    ),

                    const SizedBox(height: 20),

                    // 類型
                    _buildTextFieldSection(
                      label: "類型",
                      hint: "輸入作品類型",
                      controller: _storyTypeController,
                      icon: Icons.category,
                    ),

                    const SizedBox(height: 24),

                    // 標籤區域
                    _buildTagsSection(),

                    const SizedBox(height: 24),

                    // 簡介
                    _buildIntroSection(),

                    const SizedBox(height: 24),

                    // 統計資訊
                    _buildStatsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldSection({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SmallTitle(icon: icon, text: label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          selectAllOnFocus: false,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return CardList(
      title: "標籤",
      icon: Icons.local_offer,
      items: _data.tags,
      onAdd: _addTag,
      onRemove: _removeTag,
    );
  }

  Widget _buildIntroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SmallTitle(icon: Icons.description, text: "簡介"),
        const SizedBox(height: 8),
        TextField(
          controller: _introController,
          selectAllOnFocus: false,
          decoration: InputDecoration(
            hintText: "輸入作品簡介",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          ),
          maxLines: 6,
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final totalWords = ref.watch(totalWordsProvider);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                iconTheme: Theme.of(context).iconTheme.copyWith(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                textTheme: Theme.of(context).textTheme.copyWith(
                  titleSmall: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              child: const SmallTitle(icon: Icons.analytics, text: "統計資訊"),
            ),
            const SizedBox(height: 16),

            // 最後儲存時間
            _buildStatRow(
              "最後儲存時間",
              _data.latestSave != null
                  ? _dateFormatter.format(_data.latestSave!)
                  : "--:--:--",
              Icons.access_time,
            ),

            const Divider(height: 16),

            // 總字數
            _buildStatRow("總字數", "$totalWords 字", Icons.format_list_numbered),
            const Divider(height: 16),

            // 本章字數
            _buildStatRow("本章字數", "${_data.nowWords} 字", Icons.article),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Theme.of(
                context,
              ).colorScheme.onTertiaryContainer.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36, top: 4),
          child: Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}
