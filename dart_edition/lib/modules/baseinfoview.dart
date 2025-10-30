//
//  BaseInfoView.dart
//  MonogatariAssistant
//
//  Ported from the original SwiftUI BaseInfo page.
//  SwiftUI file ported from the original Qt BaseInfo module (single file, no DataPool)
//  Created by 部屋いる on 2025/9/30.
//

import "package:flutter/material.dart";
import "package:intl/intl.dart";

// MARK: - Model

class BaseInfoData {
  String bookName = "";
  String author = "";
  String purpose = "";
  String toRecap = "";
  String storyType = "";
  String intro = "";
  List<String> tags = [];
  DateTime? latestSave;
  int nowWords = 0; // 由 content（非空白字元數）計算

  BaseInfoData();

  void recalcNowWords(String content) {
    nowWords = content.replaceAll(RegExp(r"\s"), "").length;
  }

  bool get isEffectivelyEmpty {
    return bookName.trim().isEmpty &&
           author.trim().isEmpty &&
           storyType.trim().isEmpty &&
           intro.trim().isEmpty &&
           tags.isEmpty;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaseInfoData &&
           other.bookName == bookName &&
           other.author == author &&
           other.purpose == purpose &&
           other.toRecap == toRecap &&
           other.storyType == storyType &&
           other.intro == intro &&
           _listEquals(other.tags, tags) &&
           other.latestSave == latestSave &&
           other.nowWords == nowWords;
  }

  @override
  int get hashCode {
    return Object.hash(
      bookName,
      author,
      purpose,
      toRecap,
      storyType,
      intro,
      tags,
      latestSave,
      nowWords,
    );
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// MARK: - XML Codec (compatible with the Qt format)

class BaseInfoCodec {
  /// 序列化成與 Qt SaveFile() 兼容的 <Type> 片段
  static String? saveXML({
    required BaseInfoData data,
    required int totalWords,
    required String contentText,
    bool updateLatestSave = true,
  }) {
    if (data.isEffectivelyEmpty) return null;

    var snapshot = BaseInfoData()
      ..bookName = data.bookName
      ..author = data.author
      ..purpose = data.purpose
      ..toRecap = data.toRecap
      ..storyType = data.storyType
      ..intro = data.intro
      ..tags = List.from(data.tags)
      ..latestSave = updateLatestSave ? DateTime.now() : data.latestSave;

    snapshot.recalcNowWords(contentText);

    // Update original data if requested
    if (updateLatestSave) {
      data.latestSave = snapshot.latestSave;
      data.nowWords = snapshot.nowWords;
    }

    String escapeXml(String text) {
      return text
          .replaceAll("&", "&amp;")
          .replaceAll("<", "&lt;")
          .replaceAll(">", "&gt;")
          .replaceAll("\"", "&quot;")
          .replaceAll("'", "&apos;");
    }

    final isoSave = snapshot.latestSave?.toIso8601String() ?? "";

    final buffer = StringBuffer();
    buffer.writeln("<Type>");
    buffer.writeln("  <Name>BaseInfo</Name>");
    buffer.writeln("  <General>");
    buffer.writeln("    <BookName>${escapeXml(snapshot.bookName)}</BookName>");
    buffer.writeln("    <Author>${escapeXml(snapshot.author)}</Author>");
    buffer.writeln("    <Purpose>${escapeXml(snapshot.purpose)}</Purpose>");
    buffer.writeln("    <ToRecap>${escapeXml(snapshot.toRecap)}</ToRecap>");
    buffer.writeln("    <StoryType>${escapeXml(snapshot.storyType)}</StoryType>");
    buffer.writeln("    <Intro>${escapeXml(snapshot.intro)}</Intro>");
    if (isoSave.isNotEmpty) {
      buffer.writeln("    <LatestSave>$isoSave</LatestSave>");
    }
    buffer.writeln("  </General>");
    buffer.writeln("  <Tags>");
    for (String tag in snapshot.tags) {
      final trimmed = tag.trim();
      if (trimmed.isNotEmpty) {
        buffer.writeln("    <Tag>${escapeXml(trimmed)}</Tag>");
      }
    }
    buffer.writeln("  </Tags>");
    buffer.writeln("  <Stats>");
    buffer.writeln("    <TotalWords>$totalWords</TotalWords>");
    buffer.writeln("    <NowWords>${snapshot.nowWords}</NowWords>");
    buffer.writeln("  </Stats>");
    buffer.writeln("</Type>");

    return buffer.toString();
  }

  /// 自 <Type> 區塊解析（需 <Name>BaseInfo</Name>）
  static BaseInfoData? loadXML(String xml) {
    // 簡化的 XML 解析實作
    // 在實際應用中，建議使用專門的 XML 解析庫
    
    if (!xml.contains("<Name>BaseInfo</Name>")) {
      return null;
    }

    final data = BaseInfoData();

    // 解析各個欄位
    data.bookName = _extractTagContent(xml, "BookName") ?? "";
    data.author = _extractTagContent(xml, "Author") ?? "";
    data.purpose = _extractTagContent(xml, "Purpose") ?? "";
    data.toRecap = _extractTagContent(xml, "ToRecap") ?? "";
    data.storyType = _extractTagContent(xml, "StoryType") ?? "";
    data.intro = _extractTagContent(xml, "Intro") ?? "";

    // 解析最後儲存時間
    final latestSaveStr = _extractTagContent(xml, "LatestSave");
    if (latestSaveStr != null && latestSaveStr.isNotEmpty) {
      try {
        data.latestSave = DateTime.parse(latestSaveStr);
      } catch (e) {
        // 如果解析失敗，保持 null
      }
    }

    // 解析標籤
    final tagMatches = RegExp(r"<Tag>(.*?)</Tag>").allMatches(xml);
    for (final match in tagMatches) {
      final tag = match.group(1)?.trim();
      if (tag != null && tag.isNotEmpty) {
        data.tags.add(tag);
      }
    }

    // 解析字數
    final nowWordsStr = _extractTagContent(xml, "NowWords");
    if (nowWordsStr != null) {
      data.nowWords = int.tryParse(nowWordsStr) ?? 0;
    }

    return data;
  }

  static String? _extractTagContent(String xml, String tagName) {
    final regex = RegExp("<$tagName>(.*?)</$tagName>", dotAll: true);
    final match = regex.firstMatch(xml);
    return match?.group(1)?.trim();
  }
}

// MARK: - View

class BaseInfoView extends StatefulWidget {
  final BaseInfoData data;
  final String contentText;
  final int totalWords;
  final ValueChanged<BaseInfoData>? onDataChanged;

  const BaseInfoView({
    super.key,
    required this.data,
    required this.contentText,
    required this.totalWords,
    this.onDataChanged,
  });

  @override
  State<BaseInfoView> createState() => _BaseInfoViewState();
}

class _BaseInfoViewState extends State<BaseInfoView> {
  late BaseInfoData _data;
  final TextEditingController _newTagController = TextEditingController();
  final DateFormat _dateFormatter = DateFormat("yyyy.MM.dd HH:mm:ss");
  
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
    _data = BaseInfoData()
      ..bookName = widget.data.bookName
      ..author = widget.data.author
      ..purpose = widget.data.purpose
      ..toRecap = widget.data.toRecap
      ..storyType = widget.data.storyType
      ..intro = widget.data.intro
      ..tags = List.from(widget.data.tags)
      ..latestSave = widget.data.latestSave
      ..nowWords = widget.data.nowWords;
    
    _data.recalcNowWords(widget.contentText);
    
    // 初始化各個文字欄位的 controller
    _bookNameController = TextEditingController(text: _data.bookName);
    _authorController = TextEditingController(text: _data.author);
    _purposeController = TextEditingController(text: _data.purpose);
    _toRecapController = TextEditingController(text: _data.toRecap);
    _storyTypeController = TextEditingController(text: _data.storyType);
    _introController = TextEditingController(text: _data.intro);
    
    // 添加監聽器
    _bookNameController.addListener(() {
      _data.bookName = _bookNameController.text;
      _notifyDataChanged();
    });
    
    _authorController.addListener(() {
      _data.author = _authorController.text;
      _notifyDataChanged();
    });
    
    _purposeController.addListener(() {
      _data.purpose = _purposeController.text;
      _notifyDataChanged();
    });
    
    _toRecapController.addListener(() {
      _data.toRecap = _toRecapController.text;
      _notifyDataChanged();
    });
    
    _storyTypeController.addListener(() {
      _data.storyType = _storyTypeController.text;
      _notifyDataChanged();
    });
    
    _introController.addListener(() {
      _data.intro = _introController.text;
      _notifyDataChanged();
    });
  }

  @override
  void didUpdateWidget(BaseInfoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentText != widget.contentText) {
      setState(() {
        _data.recalcNowWords(widget.contentText);
      });
    }
  }

  @override
  void dispose() {
    _newTagController.dispose();
    _bookNameController.dispose();
    _authorController.dispose();
    _purposeController.dispose();
    _toRecapController.dispose();
    _storyTypeController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _notifyDataChanged() {
    widget.onDataChanged?.call(_data);
  }

  void _addTag() {
    final tagText = _newTagController.text.trim();
    if (tagText.isEmpty || _data.tags.contains(tagText)) {
      _newTagController.clear();
      return;
    }

    setState(() {
      _data.tags.add(tagText);
      _newTagController.clear();
    });
    _notifyDataChanged();
  }

  void _removeTag(int index) {
    setState(() {
      _data.tags.removeAt(index);
    });
    _notifyDataChanged();
  }

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
                  Icons.info_outline,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  "基本資訊",
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_offer, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              "標籤",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 現有標籤
        if (_data.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _data.tags.asMap().entries.map((entry) {
              final index = entry.key;
              final tag = entry.value;
              return Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => _removeTag(index),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // 新增標籤
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newTagController,
                decoration: InputDecoration(
                  hintText: "新增標籤",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _addTag,
              icon: const Icon(Icons.add),
              label: const Text("新增"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              "簡介",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _introController,
          decoration: InputDecoration(
            hintText: "輸入作品簡介",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          ),
          maxLines: 6,
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  "統計資訊",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 最後儲存時間
            _buildStatRow(
              "最後儲存時間",
              _data.latestSave != null
                ? _dateFormatter.format(_data.latestSave!)
                : "YYYY.MM.DD hh.mm.ss",
              Icons.access_time,
            ),
            const Divider(height: 24),
            
            // 總字數
            _buildStatRow(
              "總字數",
              "${widget.totalWords} 字",
              Icons.format_list_numbered,
            ),
            const Divider(height: 24),
            
            // 本章字數
            _buildStatRow(
              "本章字數",
              "${_data.nowWords} 字",
              Icons.article,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
      ],
    );
  }
}