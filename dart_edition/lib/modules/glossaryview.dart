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
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:path_provider/path_provider.dart";
import "package:uuid/uuid.dart";
import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:io";
import "../bin/ui_library.dart";

const String _glossaryAssetPath = "assets/jsons/glossary.json";
const String _legacyGlossaryPrefsKey = "glossary_json_v1";

enum GlossaryPolarity { positive, negative, neutral }

GlossaryPolarity parseGlossaryPolarity(String? raw) {
  switch ((raw ?? "").toLowerCase()) {
    case "positive":
      return GlossaryPolarity.positive;
    case "negative":
      return GlossaryPolarity.negative;
    case "neutral":
    default:
      return GlossaryPolarity.neutral;
  }
}

extension GlossaryPolarityX on GlossaryPolarity {
  String get rawValue {
    switch (this) {
      case GlossaryPolarity.positive:
        return "positive";
      case GlossaryPolarity.negative:
        return "negative";
      case GlossaryPolarity.neutral:
        return "neutral";
    }
  }

  String get label {
    switch (this) {
      case GlossaryPolarity.positive:
        return "正面詞";
      case GlossaryPolarity.negative:
        return "負面詞";
      case GlossaryPolarity.neutral:
        return "中性詞";
    }
  }

  IconData get icon {
    switch (this) {
      case GlossaryPolarity.positive:
        return Icons.sentiment_satisfied_alt;
      case GlossaryPolarity.negative:
        return Icons.sentiment_dissatisfied;
      case GlossaryPolarity.neutral:
        return Icons.sentiment_neutral;
    }
  }

  Color color(ColorScheme scheme) {
    switch (this) {
      case GlossaryPolarity.positive:
        return scheme.primary;
      case GlossaryPolarity.negative:
        return scheme.error;
      case GlossaryPolarity.neutral:
        return scheme.tertiary;
    }
  }
}

class GlossaryPair {
  String meaning;
  String example;

  GlossaryPair({this.meaning = "", this.example = ""});

  factory GlossaryPair.fromJson(Map<String, dynamic> json) {
    return GlossaryPair(
      meaning: json["meaning"] as String? ?? "",
      example: json["example"] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {"meaning": meaning, "example": example};
  }
}

class GlossaryEntry {
  String id;
  String term;
  GlossaryPolarity polarity;
  List<GlossaryPair> pairs;

  GlossaryEntry({
    required this.id,
    required this.term,
    required this.polarity,
    required this.pairs,
  });

  factory GlossaryEntry.fromJson(Map<String, dynamic> json) {
    final List<GlossaryPair> parsedPairs = [];
    final dynamic pairsRaw = json["pairs"];

    if (pairsRaw is List<dynamic>) {
      for (final dynamic item in pairsRaw) {
        if (item is Map<String, dynamic>) {
          parsedPairs.add(GlossaryPair.fromJson(item));
        }
      }
    }

    // 相容舊格式：meanings/examples 兩個獨立陣列。
    if (parsedPairs.isEmpty) {
      final List<String> meanings =
          (json["meanings"] as List<dynamic>? ?? <dynamic>[])
              .map((e) => e.toString())
              .toList();
      final List<String> examples =
          (json["examples"] as List<dynamic>? ?? <dynamic>[])
              .map((e) => e.toString())
              .toList();
      final int pairCount = meanings.length > examples.length
          ? meanings.length
          : examples.length;
      for (int i = 0; i < pairCount; i++) {
        final String meaning = i < meanings.length ? meanings[i] : "";
        final String example = i < examples.length ? examples[i] : "";
        if (meaning.trim().isNotEmpty || example.trim().isNotEmpty) {
          parsedPairs.add(GlossaryPair(meaning: meaning, example: example));
        }
      }
    }

    if (parsedPairs.isEmpty) {
      parsedPairs.add(GlossaryPair());
    }

    return GlossaryEntry(
      id: json["id"] as String? ?? "",
      term: json["term"] as String? ?? "",
      polarity: parseGlossaryPolarity(json["polarity"] as String?),
      pairs: parsedPairs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "term": term,
      "polarity": polarity.rawValue,
      "pairs": pairs.map((e) => e.toJson()).toList(),
    };
  }
}

class GlossaryCategory {
  final String id;
  String name;
  List<String> entryIds;
  List<GlossaryCategory> children;

  GlossaryCategory({
    required this.id,
    required this.name,
    required this.entryIds,
    required this.children,
  });

  factory GlossaryCategory.fromJson(Map<String, dynamic> json) {
    return GlossaryCategory(
      id: json["id"] as String? ?? "",
      name: json["name"] as String? ?? "",
      entryIds: (json["entryIds"] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      children: (json["children"] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(GlossaryCategory.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "entryIds": entryIds,
      "children": children.map((e) => e.toJson()).toList(),
    };
  }
}

class _GlossaryCategoryDragData {
  final String categoryId;
  final String categoryName;

  const _GlossaryCategoryDragData({
    required this.categoryId,
    required this.categoryName,
  });
}

class _CategoryEntryRef {
  final String entryId;
  final String sourceCategoryId;
  final bool isLocal;

  const _CategoryEntryRef({
    required this.entryId,
    required this.sourceCategoryId,
    required this.isLocal,
  });
}

class _VisibleCategoryRow {
  final GlossaryCategory category;
  final int depth;

  const _VisibleCategoryRow({required this.category, required this.depth});
}

class _GlossaryDecoded {
  final List<GlossaryCategory> categoryTree;
  final HashMap<String, GlossaryEntry> entryIndex;

  const _GlossaryDecoded({
    required this.categoryTree,
    required this.entryIndex,
  });
}

class GlossaryView extends StatefulWidget {
  const GlossaryView({super.key});
  @override
  State<GlossaryView> createState() => _GlossaryViewState();
}

class _GlossaryViewState extends State<GlossaryView> {
  bool _isLoading = true;
  String? _loadError;

  List<GlossaryCategory> _categoryTree = [];
  HashMap<String, GlossaryEntry> _entryIndex = HashMap();

  String? _selectedCategoryId;
  String? _selectedEntryId;

  bool _isDragging = false;
  String? _draggingCategoryId;
  final Set<String> _expandedCategoryIds = <String>{};

  Timer? _persistDebounce;

  @override
  void initState() {
    super.initState();
    _loadGlossary();
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    super.dispose();
  }

  Future<String> _getDataDirectoryPath() async {
    final Directory appDir = await getApplicationSupportDirectory();
    final Directory dataDir = Directory("${appDir.path}/Data");
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir.path;
  }

  Future<String> get _glossaryFilePath async {
    final String dataPath = await _getDataDirectoryPath();
    return "$dataPath/Glossary.json";
  }

  Future<void> _loadGlossary() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final _GlossaryDecoded decoded = await _loadFromDiskOrAsset();

      String? initialCategoryId;
      if (decoded.categoryTree.isNotEmpty) {
        initialCategoryId = decoded.categoryTree.first.id;
      }

      String? initialEntryId;
      if (initialCategoryId != null) {
        final List<_CategoryEntryRef> refs = _collectEntryRefs(
          initialCategoryId,
          decoded.categoryTree,
        );
        for (final _CategoryEntryRef ref in refs) {
          if (decoded.entryIndex.containsKey(ref.entryId)) {
            initialEntryId = ref.entryId;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _categoryTree = decoded.categoryTree;
        _entryIndex = decoded.entryIndex;
        _selectedCategoryId = initialCategoryId;
        _selectedEntryId = initialEntryId;
        _expandedCategoryIds
          ..clear()
          ..addAll(decoded.categoryTree.map((category) => category.id));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<_GlossaryDecoded> _loadFromDiskOrAsset() async {
    final String filePath = await _glossaryFilePath;
    final File file = File(filePath);

    if (await file.exists()) {
      try {
        final String raw = await file.readAsString();
        return _decodeGlossary(raw);
      } catch (_) {
        // 檔案壞掉時會回退到資源檔，避免畫面卡住。
      }
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? legacyRaw = prefs.getString(_legacyGlossaryPrefsKey);
    if (legacyRaw != null && legacyRaw.trim().isNotEmpty) {
      final _GlossaryDecoded decoded = _decodeGlossary(legacyRaw);
      await _writeGlossaryToDisk(decoded);
      return decoded;
    }

    final String assetRaw = await rootBundle.loadString(_glossaryAssetPath);
    final _GlossaryDecoded decoded = _decodeGlossary(assetRaw);
    await _writeGlossaryToDisk(decoded);
    return decoded;
  }

  _GlossaryDecoded _decodeGlossary(String rawJson) {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException("glossary.json 不是合法物件格式");
    }

    final List<GlossaryCategory> categoryTree =
        (decoded["categoryTree"] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(GlossaryCategory.fromJson)
            .toList();

    final HashMap<String, GlossaryEntry> entryIndex = HashMap();
    final dynamic entriesRaw = decoded["entries"];
    if (entriesRaw is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in entriesRaw.entries) {
        final dynamic value = entry.value;
        if (value is Map<String, dynamic>) {
          final GlossaryEntry parsed = GlossaryEntry.fromJson(value);
          final String resolvedId = parsed.id.isNotEmpty
              ? parsed.id
              : entry.key;
          parsed.id = resolvedId;
          entryIndex[entry.key] = parsed;
          if (resolvedId != entry.key) {
            entryIndex[resolvedId] = parsed;
          }
        }
      }
    }

    return _GlossaryDecoded(categoryTree: categoryTree, entryIndex: entryIndex);
  }

  Future<void> _writeGlossaryToDisk(_GlossaryDecoded decoded) async {
    final String filePath = await _glossaryFilePath;
    final File file = File(filePath);
    final Map<String, dynamic> payload = {
      "version": 1,
      "categoryTree": decoded.categoryTree.map((e) => e.toJson()).toList(),
      "entries": {
        for (final MapEntry<String, GlossaryEntry> entry
            in decoded.entryIndex.entries)
          entry.key: entry.value.toJson(),
      },
    };
    await file.writeAsString(jsonEncode(payload));
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 240), () {
      unawaited(_persistGlossaryNow());
    });
  }

  Future<void> _persistGlossaryNow() async {
    final String filePath = await _glossaryFilePath;
    final File file = File(filePath);
    final Map<String, dynamic> payload = {
      "version": 1,
      "categoryTree": _categoryTree.map((e) => e.toJson()).toList(),
      "entries": {
        for (final MapEntry<String, GlossaryEntry> entry in _entryIndex.entries)
          entry.key: entry.value.toJson(),
      },
    };
    await file.writeAsString(jsonEncode(payload));
  }

  GlossaryCategory? _findCategoryById(String id, List<GlossaryCategory> nodes) {
    for (final GlossaryCategory node in nodes) {
      if (node.id == id) return node;
      final GlossaryCategory? found = _findCategoryById(id, node.children);
      if (found != null) return found;
    }
    return null;
  }

  bool _isDescendantCategory(String sourceId, String targetId) {
    final GlossaryCategory? source = _findCategoryById(sourceId, _categoryTree);
    if (source == null) return false;

    bool walk(GlossaryCategory node) {
      if (node.id == targetId) return true;
      for (final GlossaryCategory child in node.children) {
        if (walk(child)) return true;
      }
      return false;
    }

    return walk(source);
  }

  void _moveCategoryTo(
    String sourceId,
    String targetId,
    DropPosition position,
  ) {
    if (sourceId == targetId || _isDescendantCategory(sourceId, targetId)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("無法移動到自己或自己的子目錄")));
      return;
    }

    setState(() {
      GlossaryCategory? sourceNode;

      bool removeNode(List<GlossaryCategory> nodes) {
        for (int i = 0; i < nodes.length; i++) {
          if (nodes[i].id == sourceId) {
            sourceNode = nodes[i];
            nodes.removeAt(i);
            return true;
          }
          if (removeNode(nodes[i].children)) {
            return true;
          }
        }
        return false;
      }

      final bool removed = removeNode(_categoryTree);
      if (!removed || sourceNode == null) return;

      bool inserted = false;
      if (position == DropPosition.child) {
        bool insertAsChild(List<GlossaryCategory> nodes) {
          for (final GlossaryCategory node in nodes) {
            if (node.id == targetId) {
              node.children.add(sourceNode!);
              return true;
            }
            if (insertAsChild(node.children)) {
              return true;
            }
          }
          return false;
        }

        inserted = insertAsChild(_categoryTree);
      } else {
        bool insertAsSibling(List<GlossaryCategory> nodes) {
          for (int i = 0; i < nodes.length; i++) {
            if (nodes[i].id == targetId) {
              final int targetIndex = position == DropPosition.before
                  ? i
                  : i + 1;
              nodes.insert(targetIndex, sourceNode!);
              return true;
            }
            if (insertAsSibling(nodes[i].children)) {
              return true;
            }
          }
          return false;
        }

        inserted = insertAsSibling(_categoryTree);
      }

      if (!inserted) {
        _categoryTree.add(sourceNode!);
      } else {
        _expandedCategoryIds.add(targetId);
      }
    });

    _schedulePersist();
  }

  List<_VisibleCategoryRow> _collectVisibleCategories() {
    final List<_VisibleCategoryRow> rows = [];

    void walk(List<GlossaryCategory> nodes, int depth) {
      for (final GlossaryCategory category in nodes) {
        rows.add(_VisibleCategoryRow(category: category, depth: depth));
        final bool expanded = _expandedCategoryIds.contains(category.id);
        if (expanded && category.children.isNotEmpty) {
          walk(category.children, depth + 1);
        }
      }
    }

    walk(_categoryTree, 0);
    return rows;
  }

  List<_CategoryEntryRef> _collectEntryRefs(
    String categoryId,
    List<GlossaryCategory> nodes,
  ) {
    final GlossaryCategory? root = _findCategoryById(categoryId, nodes);
    if (root == null) return [];

    final List<_CategoryEntryRef> refs = [];
    final Set<String> seen = <String>{};

    void walk(GlossaryCategory category, {required bool isLocal}) {
      for (final String entryId in category.entryIds) {
        if (seen.add(entryId)) {
          refs.add(
            _CategoryEntryRef(
              entryId: entryId,
              sourceCategoryId: category.id,
              isLocal: isLocal,
            ),
          );
        }
      }

      for (final GlossaryCategory child in category.children) {
        walk(child, isLocal: false);
      }
    }

    walk(root, isLocal: true);
    return refs;
  }

  int _countSubtreeEntries(GlossaryCategory category) {
    int total = category.entryIds.length;
    for (final GlossaryCategory child in category.children) {
      total += _countSubtreeEntries(child);
    }
    return total;
  }

  String _categoryName(String categoryId) {
    final GlossaryCategory? category = _findCategoryById(
      categoryId,
      _categoryTree,
    );
    return category?.name ?? "未知類別";
  }

  Set<String> _collectReferencedEntryIds() {
    final Set<String> refs = <String>{};

    void walk(List<GlossaryCategory> nodes) {
      for (final GlossaryCategory node in nodes) {
        refs.addAll(node.entryIds);
        walk(node.children);
      }
    }

    walk(_categoryTree);
    return refs;
  }

  String _createId() => const Uuid().v4();

  Future<String?> _showTextInputDialog({
    required String title,
    required String hint,
    String initialValue = "",
  }) async {
    String draftValue = initialValue;

    final String? value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextFormField(
            autofocus: true,
            initialValue: initialValue,
            decoration: InputDecoration(hintText: hint),
            onChanged: (v) {
              draftValue = v;
            },
            onFieldSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("取消"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(draftValue),
              child: const Text("確定"),
            ),
          ],
        );
      },
    );
    return value?.trim();
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("取消"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("刪除"),
            ),
          ],
        );
      },
    );
    return accepted ?? false;
  }

  void _selectCategory(String categoryId) {
    final List<_CategoryEntryRef> refs = _collectEntryRefs(
      categoryId,
      _categoryTree,
    );

    String? nextEntryId;
    for (final _CategoryEntryRef ref in refs) {
      if (_entryIndex.containsKey(ref.entryId)) {
        nextEntryId = ref.entryId;
        break;
      }
    }

    setState(() {
      _selectedCategoryId = categoryId;
      _selectedEntryId = nextEntryId;
      _expandedCategoryIds.add(categoryId);
    });
  }

  Future<void> _addCategory({String? parentId}) async {
    final String? name = await _showTextInputDialog(
      title: parentId == null ? "新增分類" : "新增子分類",
      hint: "輸入分類名稱",
    );
    if (!mounted) return;
    if (name == null || name.isEmpty) return;

    final GlossaryCategory newNode = GlossaryCategory(
      id: _createId(),
      name: name,
      entryIds: [],
      children: [],
    );

    setState(() {
      if (parentId == null) {
        _categoryTree.add(newNode);
      } else {
        final GlossaryCategory? parent = _findCategoryById(
          parentId,
          _categoryTree,
        );
        if (parent != null) {
          parent.children.add(newNode);
          _expandedCategoryIds.add(parent.id);
        } else {
          _categoryTree.add(newNode);
        }
      }
      _selectedCategoryId = newNode.id;
      _selectedEntryId = null;
    });

    _schedulePersist();
  }

  Future<void> _renameCategory(String categoryId) async {
    final GlossaryCategory? category = _findCategoryById(
      categoryId,
      _categoryTree,
    );
    if (category == null) return;

    final String? name = await _showTextInputDialog(
      title: "重新命名分類",
      hint: "分類名稱",
      initialValue: category.name,
    );
    if (!mounted) return;
    if (name == null || name.isEmpty) return;

    setState(() {
      category.name = name;
    });
    _schedulePersist();
  }

  Future<void> _deleteCategory(String categoryId) async {
    final GlossaryCategory? category = _findCategoryById(
      categoryId,
      _categoryTree,
    );
    if (category == null) return;

    final bool confirmed = await _showConfirmDialog(
      title: "刪除分類",
      message: "確定要刪除「${category.name}」及其子分類嗎？",
    );
    if (!mounted) return;
    if (!confirmed) return;

    GlossaryCategory? removeNode(List<GlossaryCategory> nodes) {
      for (int i = 0; i < nodes.length; i++) {
        if (nodes[i].id == categoryId) {
          final GlossaryCategory removed = nodes[i];
          nodes.removeAt(i);
          return removed;
        }
        final GlossaryCategory? nested = removeNode(nodes[i].children);
        if (nested != null) return nested;
      }
      return null;
    }

    setState(() {
      removeNode(_categoryTree);
      final Set<String> refs = _collectReferencedEntryIds();
      _entryIndex.removeWhere((key, _) => !refs.contains(key));

      if (_selectedCategoryId == categoryId) {
        _selectedCategoryId = _categoryTree.isNotEmpty
            ? _categoryTree.first.id
            : null;
      }

      if (_selectedCategoryId != null) {
        final List<_CategoryEntryRef> refsForSelected = _collectEntryRefs(
          _selectedCategoryId!,
          _categoryTree,
        );
        _selectedEntryId = null;
        for (final _CategoryEntryRef ref in refsForSelected) {
          if (_entryIndex.containsKey(ref.entryId)) {
            _selectedEntryId = ref.entryId;
            break;
          }
        }
      } else {
        _selectedEntryId = null;
      }
    });

    _schedulePersist();
  }

  Future<void> _addEntryToSelectedCategory() async {
    if (_selectedCategoryId == null) return;
    final GlossaryCategory? category = _findCategoryById(
      _selectedCategoryId!,
      _categoryTree,
    );
    if (category == null) return;

    final String? term = await _showTextInputDialog(
      title: "新增詞條",
      hint: "輸入詞條名稱",
      initialValue: "",
    );
    if (!mounted) return;
    if (term == null || term.isEmpty) return;

    final String entryId = _createId();
    final GlossaryEntry entry = GlossaryEntry(
      id: entryId,
      term: term,
      polarity: GlossaryPolarity.neutral,
      pairs: [GlossaryPair()],
    );

    setState(() {
      _entryIndex[entryId] = entry;
      category.entryIds.add(entryId);
      _selectedEntryId = entryId;
    });

    _schedulePersist();
  }

  Future<void> _removeEntryFromCategory(_CategoryEntryRef ref) async {
    final GlossaryEntry? entry = _entryIndex[ref.entryId];
    if (entry == null) return;

    final bool confirmed = await _showConfirmDialog(
      title: "移除詞條",
      message:
          "確定要從「${_categoryName(ref.sourceCategoryId)}」移除「${entry.term}」嗎？",
    );
    if (!mounted) return;
    if (!confirmed) return;

    setState(() {
      final GlossaryCategory? source = _findCategoryById(
        ref.sourceCategoryId,
        _categoryTree,
      );
      source?.entryIds.remove(ref.entryId);

      final Set<String> allRefs = _collectReferencedEntryIds();
      if (!allRefs.contains(ref.entryId)) {
        _entryIndex.remove(ref.entryId);
      }

      if (_selectedEntryId == ref.entryId) {
        _selectedEntryId = null;
        if (_selectedCategoryId != null) {
          final List<_CategoryEntryRef> refs = _collectEntryRefs(
            _selectedCategoryId!,
            _categoryTree,
          );
          for (final _CategoryEntryRef candidate in refs) {
            if (_entryIndex.containsKey(candidate.entryId)) {
              _selectedEntryId = candidate.entryId;
              break;
            }
          }
        }
      }
    });

    _schedulePersist();
  }

  GlossaryEntry? get _selectedEntry {
    if (_selectedEntryId == null) return null;
    return _entryIndex[_selectedEntryId!];
  }

  void _updateTerm(String value) {
    final GlossaryEntry? entry = _selectedEntry;
    if (entry == null || entry.term == value) return;

    setState(() {
      entry.term = value;
    });
    _schedulePersist();
  }

  Widget _buildPairEditorList(GlossaryEntry selectedEntry) {
    return Column(
      children: List.generate(selectedEntry.pairs.length, (index) {
        final GlossaryPair pair = selectedEntry.pairs[index];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "第 ${index + 1} 組",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: "刪除此組",
                      onPressed: selectedEntry.pairs.length <= 1
                          ? null
                          : () => _removePair(index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  key: ValueKey("meaning_${selectedEntry.id}_$index"),
                  initialValue: pair.meaning,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "意義",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _updatePairMeaning(index, value),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: ValueKey("example_${selectedEntry.id}_$index"),
                  initialValue: pair.example,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "例句",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _updatePairExample(index, value),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _setPolarity(GlossaryPolarity value) {
    final GlossaryEntry? entry = _selectedEntry;
    if (entry == null || entry.polarity == value) return;

    setState(() {
      entry.polarity = value;
    });
    _schedulePersist();
  }

  void _updatePairMeaning(int index, String value) {
    final GlossaryEntry? entry = _selectedEntry;
    if (entry == null || index < 0 || index >= entry.pairs.length) return;

    if (entry.pairs[index].meaning == value) return;
    setState(() {
      entry.pairs[index].meaning = value;
    });
    _schedulePersist();
  }

  void _updatePairExample(int index, String value) {
    final GlossaryEntry? entry = _selectedEntry;
    if (entry == null || index < 0 || index >= entry.pairs.length) return;

    if (entry.pairs[index].example == value) return;
    setState(() {
      entry.pairs[index].example = value;
    });
    _schedulePersist();
  }

  void _addPair() {
    final GlossaryEntry? entry = _selectedEntry;
    if (entry == null) return;

    setState(() {
      entry.pairs.add(GlossaryPair());
    });
    _schedulePersist();
  }

  void _removePair(int index) {
    final GlossaryEntry? entry = _selectedEntry;
    if (entry == null || index < 0 || index >= entry.pairs.length) return;
    if (entry.pairs.length <= 1) return;

    setState(() {
      entry.pairs.removeAt(index);
    });
    _schedulePersist();
  }

  Widget _buildWarningCard() {
    return Card(
      elevation: 0,
      color: Colors.redAccent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.yellow),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "本功能正在開發中，使用時可能出現錯誤。",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTreeCard() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<_VisibleCategoryRow> rows = _collectVisibleCategories();

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: MediumTitle(icon: Icons.folder, text: "詞語類別"),
                ),
                IconButton(
                  tooltip: "新增根分類",
                  onPressed: () => _addCategory(),
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
                IconButton(
                  tooltip: "新增子分類",
                  onPressed: _selectedCategoryId == null
                      ? null
                      : () => _addCategory(parentId: _selectedCategoryId),
                  icon: const Icon(Icons.create_new_folder),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "長按卡片可拖曳，支援排序與改為子目錄。",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text("尚無詞語類別", style: Theme.of(context).textTheme.bodyMedium)
            else
              Column(
                children: rows.map((row) => _buildCategoryRow(row)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(_VisibleCategoryRow row) {
    final GlossaryCategory category = row.category;
    final bool isSelected = _selectedCategoryId == category.id;
    final bool hasChildren = category.children.isNotEmpty;
    final bool isExpanded = _expandedCategoryIds.contains(category.id);
    final int totalEntries = _countSubtreeEntries(category);

    return DraggableCardNode<_GlossaryCategoryDragData>(
      key: ValueKey(category.id),
      dragData: _GlossaryCategoryDragData(
        categoryId: category.id,
        categoryName: category.name,
      ),
      nodeId: category.id,
      nodeType: hasChildren ? NodeType.folder : NodeType.item,
      leading: Icon(
        hasChildren ? Icons.folder_copy_outlined : Icons.folder_open_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: GestureDetector(
        onDoubleTap: () => _renameCategory(category.id),
        child: Text(
          category.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      subtitle: Text(
        "共 $totalEntries 條",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: PopupMenuButton<String>(
        tooltip: "分類操作",
        onSelected: (value) {
          if (value == "rename") {
            _renameCategory(category.id);
            return;
          }
          if (value == "delete") {
            _deleteCategory(category.id);
            return;
          }
          if (value == "toggle") {
            setState(() {
              if (isExpanded) {
                _expandedCategoryIds.remove(category.id);
              } else {
                _expandedCategoryIds.add(category.id);
              }
            });
          }
        },
        itemBuilder: (context) {
          return [
            if (hasChildren)
              PopupMenuItem<String>(
                value: "toggle",
                child: Text(isExpanded ? "收合子分類" : "展開子分類"),
              ),
            const PopupMenuItem<String>(value: "rename", child: Text("重命名")),
            const PopupMenuItem<String>(value: "delete", child: Text("刪除分類")),
          ];
        },
        icon: const Icon(Icons.more_horiz),
      ),
      isSelected: isSelected,
      isDragging: _isDragging,
      isThisDragging: _draggingCategoryId == category.id,
      isDragForbidden:
          _isDragging &&
          _draggingCategoryId != null &&
          _isDescendantCategory(_draggingCategoryId!, category.id),
      onClicked: () => _selectCategory(category.id),
      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _draggingCategoryId = category.id;
        });
      },
      onDragEnd: () {
        setState(() {
          _isDragging = false;
          _draggingCategoryId = null;
        });
      },
      onWillAccept: (data, position) {
        if (data.categoryId == category.id) return false;
        if (_isDescendantCategory(data.categoryId, category.id)) return false;
        return true;
      },
      onAccept: (data, position) {
        _moveCategoryTo(data.categoryId, category.id, position);
        final String actionText = switch (position) {
          DropPosition.before => "移動到前方",
          DropPosition.child => "移動到子目錄",
          DropPosition.after => "移動到後方",
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("「${data.categoryName}」已$actionText"),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      getDropZoneSize: (position) {
        switch (position) {
          case DropPosition.before:
            return 0.3;
          case DropPosition.child:
            return 0.4;
          case DropPosition.after:
            return 0.3;
        }
      },
      indent: row.depth * 16.0,
    );
  }

  Widget _buildEntryListCard() {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    if (_selectedCategoryId == null) {
      return Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MediumTitle(icon: Icons.format_list_bulleted, text: "詞語條目"),
              SizedBox(height: 12),
              Text("請先選擇詞語類別。"),
            ],
          ),
        ),
      );
    }

    final List<_CategoryEntryRef> refs = _collectEntryRefs(
      _selectedCategoryId!,
      _categoryTree,
    );
    final List<_CategoryEntryRef> visibleRefs = refs
        .where((ref) => _entryIndex.containsKey(ref.entryId))
        .toList();

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: MediumTitle(
                    icon: Icons.format_list_bulleted,
                    text: "詞語條目",
                  ),
                ),
                IconButton(
                  tooltip: "新增詞條",
                  onPressed: _addEntryToSelectedCategory,
                  icon: const Icon(Icons.post_add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "同時顯示本目錄與子目錄條目，底色區分來源。",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (visibleRefs.isEmpty)
              Text("此類別目前沒有詞條。", style: Theme.of(context).textTheme.bodyMedium)
            else
              Column(
                children: visibleRefs.map((ref) {
                  final GlossaryEntry entry = _entryIndex[ref.entryId]!;
                  final bool isSelected = _selectedEntryId == entry.id;
                  final Color sourceColor = ref.isLocal
                      ? scheme.primaryContainer.withValues(alpha: 0.52)
                      : scheme.tertiaryContainer.withValues(alpha: 0.52);
                  final String summary = entry.pairs.isEmpty
                      ? "尚未填寫意義"
                      : (entry.pairs.first.meaning.trim().isEmpty
                            ? "尚未填寫意義"
                            : entry.pairs.first.meaning);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      color: sourceColor,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isSelected
                              ? scheme.primary
                              : Colors.transparent,
                          width: 1.8,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          entry.polarity.icon,
                          color: entry.polarity.color(scheme),
                        ),
                        title: Text(
                          entry.term,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ref.isLocal
                                  ? "來源：本目錄"
                                  : "來源：子目錄 ${_categoryName(ref.sourceCategoryId)}",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: "從此分類移除",
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _removeEntryFromCategory(ref),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedEntryId = entry.id;
                          });
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryEditorCard() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final GlossaryEntry? selectedEntry = _selectedEntry;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MediumTitle(icon: Icons.library_books, text: "詞語解釋、例句"),
            const SizedBox(height: 12),
            if (selectedEntry == null)
              Text("請從上方選擇一個詞條。", style: Theme.of(context).textTheme.bodyMedium)
            else ...[
              TextFormField(
                key: ValueKey("term_${selectedEntry.id}"),
                initialValue: selectedEntry.term,
                decoration: const InputDecoration(
                  labelText: "詞條名稱",
                  border: OutlineInputBorder(),
                ),
                onChanged: _updateTerm,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GlossaryPolarity>(
                value: selectedEntry.polarity,
                decoration: const InputDecoration(
                  labelText: "詞性分類",
                  border: OutlineInputBorder(),
                ),
                items: GlossaryPolarity.values.map((polarity) {
                  return DropdownMenuItem<GlossaryPolarity>(
                    value: polarity,
                    child: Row(
                      children: [
                        Icon(
                          polarity.icon,
                          size: 18,
                          color: polarity.color(scheme),
                        ),
                        const SizedBox(width: 8),
                        Text(polarity.label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _setPolarity(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    "意義 + 例句組",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addPair,
                    icon: const Icon(Icons.add),
                    label: const Text("新增一組"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPairEditorList(selectedEntry),
            ],
          ],
        ),
      ),
    );
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 36),
                const SizedBox(height: 12),
                const Text("讀取詞語資料失敗"),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadGlossary,
                  child: const Text("重試"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: LargeTitle(
                icon: Icons.library_books_outlined,
                text: "詞語參考",
              ),
            ),
            const SizedBox(height: 32),
            _buildWarningCard(),
            const SizedBox(height: 20),
            _buildCategoryTreeCard(),
            const SizedBox(height: 12),
            _buildEntryListCard(),
            const SizedBox(height: 12),
            _buildEntryEditorCard(),
          ],
        ),
      ),
    );
  }
}
