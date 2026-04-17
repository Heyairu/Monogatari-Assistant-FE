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
import "dart:convert";
import "dart:io";
import "package:path_provider/path_provider.dart";
import "package:uuid/uuid.dart";
import "package:xml/xml.dart" as xml;
import "../bin/ui_library.dart";
import "package:logging/logging.dart";
import "../presentation/providers/project_state_providers.dart";

final _log = Logger("PlanView");

class ForeshadowItem {
  String id;
  String title;
  String note;
  bool isRevealed;

  ForeshadowItem({
    String? id,
    this.title = "",
    this.note = "",
    this.isRevealed = false,
  }) : id = id ?? const Uuid().v4();

  ForeshadowItem copyWith({
    String? id,
    String? title,
    String? note,
    bool? isRevealed,
  }) {
    return ForeshadowItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      isRevealed: isRevealed ?? this.isRevealed,
    );
  }
}

class UpdatePlanItem {
  String id;
  String title;
  String note;
  bool isDone;

  UpdatePlanItem({
    String? id,
    this.title = "",
    this.note = "",
    this.isDone = false,
  }) : id = id ?? const Uuid().v4();

  UpdatePlanItem copyWith({
    String? id,
    String? title,
    String? note,
    bool? isDone,
  }) {
    return UpdatePlanItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      isDone: isDone ?? this.isDone,
    );
  }
}

class _ForeshadowDragData {
  final String id;

  const _ForeshadowDragData({required this.id});
}

class _UpdatePlanDragData {
  final String id;

  const _UpdatePlanDragData({required this.id});
}

class InspirationFolder {
  String id;
  String name;

  InspirationFolder({String? id, this.name = ""})
    : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {"id": id, "name": name};

  factory InspirationFolder.fromJson(Map<String, dynamic> json) {
    return InspirationFolder(
      id: json["id"] as String?,
      name: json["name"] as String? ?? "",
    );
  }
}

class InspirationNote {
  String id;
  String title;
  String content;
  String? folderId;

  InspirationNote({
    String? id,
    this.title = "",
    this.content = "",
    this.folderId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "content": content,
    "folderId": folderId,
  };

  factory InspirationNote.fromJson(Map<String, dynamic> json) {
    return InspirationNote(
      id: json["id"] as String?,
      title: json["title"] as String? ?? "",
      content: json["content"] as String? ?? "",
      folderId: json["folderId"] as String?,
    );
  }
}

enum _InspirationLayerType { folder, note }

class _InspirationDragData {
  final String id;
  final _InspirationLayerType type;

  const _InspirationDragData({required this.id, required this.type});

  String get nodeKey => "${type.name}:$id";
}

class _InspirationLayerEntry {
  final String id;
  final _InspirationLayerType type;
  final String title;
  final String? subtitle;
  final int depth;
  final String? folderContextId;

  const _InspirationLayerEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.depth,
    required this.folderContextId,
  });

  factory _InspirationLayerEntry.folder({
    required InspirationFolder folder,
    required int noteCount,
    required int depth,
  }) {
    return _InspirationLayerEntry(
      id: folder.id,
      type: _InspirationLayerType.folder,
      title: folder.name.isEmpty ? "（未命名）" : folder.name,
      subtitle: "$noteCount 則靈感",
      depth: depth,
      folderContextId: folder.id,
    );
  }

  factory _InspirationLayerEntry.note({
    required InspirationNote note,
    required int depth,
    required String? folderContextId,
  }) {
    return _InspirationLayerEntry(
      id: note.id,
      type: _InspirationLayerType.note,
      title: note.title.isEmpty ? "（未命名）" : note.title,
      subtitle: note.content.isEmpty ? null : note.content,
      depth: depth,
      folderContextId: folderContextId,
    );
  }

  String get nodeKey => "${type.name}:$id";
}

class PlanProjectData {
  final List<ForeshadowItem> foreshadows;
  final List<UpdatePlanItem> updatePlans;

  const PlanProjectData({required this.foreshadows, required this.updatePlans});
}

class PlanCodec {
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

  static String? saveXML(
    List<ForeshadowItem> foreshadows,
    List<UpdatePlanItem> updatePlans,
  ) {
    if (foreshadows.isEmpty && updatePlans.isEmpty) return null;

    final builder = xml.XmlBuilder();
    builder.element(
      "Type",
      nest: () {
        builder.element("Name", nest: "PlanSettings");

        if (foreshadows.isNotEmpty) {
          builder.element(
            "ForeshadowList",
            nest: () {
              for (final item in foreshadows) {
                builder.element(
                  "Foreshadow",
                  attributes: {
                    "ID": item.id,
                    "Revealed": item.isRevealed.toString(),
                  },
                  nest: () {
                    _writeTextElement(builder, "Title", item.title);
                    if (item.note.isNotEmpty) {
                      _writeTextElement(builder, "Note", item.note);
                    }
                  },
                );
              }
            },
          );
        }

        if (updatePlans.isNotEmpty) {
          builder.element(
            "UpdatePlanList",
            nest: () {
              for (final item in updatePlans) {
                builder.element(
                  "UpdatePlan",
                  attributes: {"ID": item.id, "Done": item.isDone.toString()},
                  nest: () {
                    _writeTextElement(builder, "Title", item.title);
                    if (item.note.isNotEmpty) {
                      _writeTextElement(builder, "Note", item.note);
                    }
                  },
                );
              }
            },
          );
        }
      },
    );

    return builder.buildDocument().toXmlString(pretty: true, indent: "  ");
  }

  static PlanProjectData? loadXML(String content) {
    try {
      final document = xml.XmlDocument.parse(content);
      final typeElement = document.findAllElements("Type").firstOrNull;
      if (typeElement == null) return null;

      final nameElement = typeElement.findAllElements("Name").firstOrNull;
      if (nameElement?.innerText != "PlanSettings") return null;

      final foreshadows = <ForeshadowItem>[];
      final updatePlans = <UpdatePlanItem>[];

      final foreshadowListElement = typeElement
          .findElements("ForeshadowList")
          .firstOrNull;
      if (foreshadowListElement != null) {
        for (final node in foreshadowListElement.findElements("Foreshadow")) {
          foreshadows.add(
            ForeshadowItem(
              id: node.getAttribute("ID"),
              title: _readElementText(node.findElements("Title").firstOrNull),
              note: _readElementText(node.findElements("Note").firstOrNull),
              isRevealed:
                  (node.getAttribute("Revealed") ?? "false").toLowerCase() ==
                  "true",
            ),
          );
        }
      }

      final updatePlanListElement = typeElement
          .findElements("UpdatePlanList")
          .firstOrNull;
      if (updatePlanListElement != null) {
        for (final node in updatePlanListElement.findElements("UpdatePlan")) {
          updatePlans.add(
            UpdatePlanItem(
              id: node.getAttribute("ID"),
              title: _readElementText(node.findElements("Title").firstOrNull),
              note: _readElementText(node.findElements("Note").firstOrNull),
              isDone:
                  (node.getAttribute("Done") ?? "false").toLowerCase() ==
                  "true",
            ),
          );
        }
      }

      return PlanProjectData(
        foreshadows: foreshadows,
        updatePlans: updatePlans,
      );
    } catch (e) {
      _log.warning("Error parsing PlanSettings XML: $e");
      return null;
    }
  }
}

class PlanView extends ConsumerStatefulWidget {
  final void Function(List<ForeshadowItem>, List<UpdatePlanItem>)? onChanged;

  const PlanView({
    super.key,
    this.onChanged,
  });

  @override
  ConsumerState<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends ConsumerState<PlanView> {
  String? selectedForeshadowId;
  String? selectedUpdatePlanId;
  String? selectedFolderId;
  String? selectedInspirationId;
  final Set<String> collapsedFolderIds = <String>{};
  bool _isInspirationDragging = false;
  String? _draggingInspirationNodeKey;
  bool _isForeshadowDragging = false;
  String? _draggingForeshadowId;
  bool _isUpdatePlanDragging = false;
  String? _draggingUpdatePlanId;
  bool _showRootDirectory = false;
  List<String> _rootLayerOrder = [];
  List<ForeshadowItem> _foreshadowItems = [];
  List<UpdatePlanItem> _updatePlanItems = [];
  bool _isCommittingLocalChange = false;
  ProviderSubscription<List<ForeshadowItem>>? _foreshadowSubscription;
  ProviderSubscription<List<UpdatePlanItem>>? _updatePlanSubscription;

  final TextEditingController foreshadowTitleController =
      TextEditingController();
  final TextEditingController foreshadowNoteController =
      TextEditingController();
  final TextEditingController updatePlanTitleController =
      TextEditingController();
  final TextEditingController updatePlanNoteController =
      TextEditingController();
  final TextEditingController inspirationTitleController =
      TextEditingController();
  final TextEditingController inspirationContentController =
      TextEditingController();

  List<InspirationFolder> inspirationFolders = [];
  List<InspirationNote> inspirationNotes = [];
  bool _isLoadingInspiration = true;

  @override
  void initState() {
    super.initState();
    _foreshadowItems = _copyForeshadowItems(ref.read(foreshadowDataProvider));
    _updatePlanItems = _copyUpdatePlanItems(ref.read(updatePlanDataProvider));

    foreshadowTitleController.addListener(_onForeshadowTitleChanged);
    foreshadowNoteController.addListener(_onForeshadowNoteChanged);
    updatePlanTitleController.addListener(_onUpdatePlanTitleChanged);
    updatePlanNoteController.addListener(_onUpdatePlanNoteChanged);
    inspirationTitleController.addListener(_onInspirationTitleChanged);
    inspirationContentController.addListener(_onInspirationContentChanged);

    _foreshadowSubscription = ref.listenManual<List<ForeshadowItem>>(
      foreshadowDataProvider,
      (previous, next) {
        if (_isCommittingLocalChange) {
          return;
        }
        setState(() {
          _foreshadowItems = _copyForeshadowItems(next);
          _syncSelectionAfterDataUpdate();
        });
      },
    );

    _updatePlanSubscription = ref.listenManual<List<UpdatePlanItem>>(
      updatePlanDataProvider,
      (previous, next) {
        if (_isCommittingLocalChange) {
          return;
        }
        setState(() {
          _updatePlanItems = _copyUpdatePlanItems(next);
          _syncSelectionAfterDataUpdate();
        });
      },
    );

    _loadInspirationFromDisk();
  }

  void _syncSelectionAfterDataUpdate() {
    if (_selectedForeshadow == null && selectedForeshadowId != null) {
      selectedForeshadowId = null;
      _syncForeshadowControllers();
    }
    if (_selectedUpdatePlan == null && selectedUpdatePlanId != null) {
      selectedUpdatePlanId = null;
      _syncUpdatePlanControllers();
    }
  }

  @override
  void dispose() {
    _foreshadowSubscription?.close();
    _updatePlanSubscription?.close();

    foreshadowTitleController.removeListener(_onForeshadowTitleChanged);
    foreshadowNoteController.removeListener(_onForeshadowNoteChanged);
    updatePlanTitleController.removeListener(_onUpdatePlanTitleChanged);
    updatePlanNoteController.removeListener(_onUpdatePlanNoteChanged);
    inspirationTitleController.removeListener(_onInspirationTitleChanged);
    inspirationContentController.removeListener(_onInspirationContentChanged);

    foreshadowTitleController.dispose();
    foreshadowNoteController.dispose();
    updatePlanTitleController.dispose();
    updatePlanNoteController.dispose();
    inspirationTitleController.dispose();
    inspirationContentController.dispose();
    super.dispose();
  }

  ForeshadowItem? get _selectedForeshadow {
    if (selectedForeshadowId == null) return null;
    for (final item in _foreshadowItems) {
      if (item.id == selectedForeshadowId) return item;
    }
    return null;
  }

  UpdatePlanItem? get _selectedUpdatePlan {
    if (selectedUpdatePlanId == null) return null;
    for (final item in _updatePlanItems) {
      if (item.id == selectedUpdatePlanId) return item;
    }
    return null;
  }

  InspirationNote? get _selectedInspiration {
    if (selectedInspirationId == null) return null;
    for (final item in inspirationNotes) {
      if (item.id == selectedInspirationId) return item;
    }
    return null;
  }

  String _folderRootKey(String folderId) => "F:$folderId";

  String _noteRootKey(String noteId) => "N:$noteId";

  String _extractRootId(String key) {
    final idx = key.indexOf(":");
    if (idx == -1 || idx == key.length - 1) return key;
    return key.substring(idx + 1);
  }

  void _ensureRootLayerOrderIntegrity() {
    final validFolderKeys = inspirationFolders
        .map((folder) => _folderRootKey(folder.id))
        .toSet();
    final validRootNoteKeys = inspirationNotes
        .where((note) => note.folderId == null)
        .map((note) => _noteRootKey(note.id))
        .toSet();

    final validKeys = <String>{...validFolderKeys, ...validRootNoteKeys};
    _rootLayerOrder = _rootLayerOrder.where(validKeys.contains).toList();

    for (final folder in inspirationFolders) {
      final key = _folderRootKey(folder.id);
      if (!_rootLayerOrder.contains(key)) {
        _rootLayerOrder.add(key);
      }
    }

    for (final note in inspirationNotes.where((n) => n.folderId == null)) {
      final key = _noteRootKey(note.id);
      if (!_rootLayerOrder.contains(key)) {
        _rootLayerOrder.add(key);
      }
    }
  }

  void _moveRootLayerKeyBeforeAfter(
    String draggedKey,
    String targetKey,
    bool isBefore,
  ) {
    if (draggedKey == targetKey) return;
    _rootLayerOrder.remove(draggedKey);
    final targetIndex = _rootLayerOrder.indexOf(targetKey);
    if (targetIndex == -1) {
      _rootLayerOrder.add(draggedKey);
      return;
    }
    final insertIndex = isBefore ? targetIndex : targetIndex + 1;
    _rootLayerOrder.insert(insertIndex, draggedKey);
  }

  void _notifyProjectChanged() {
    final foreshadowSnapshot = _copyForeshadowItems(_foreshadowItems);
    final updatePlanSnapshot = _copyUpdatePlanItems(_updatePlanItems);

    _isCommittingLocalChange = true;
    ref.read(foreshadowDataProvider.notifier).setForeshadowData(
      foreshadowSnapshot,
    );
    ref.read(updatePlanDataProvider.notifier).setUpdatePlanData(
      updatePlanSnapshot,
    );
    widget.onChanged?.call(foreshadowSnapshot, updatePlanSnapshot);
    _isCommittingLocalChange = false;
  }

  List<ForeshadowItem> _copyForeshadowItems(List<ForeshadowItem> source) {
    return source.map((item) => item.copyWith()).toList();
  }

  List<UpdatePlanItem> _copyUpdatePlanItems(List<UpdatePlanItem> source) {
    return source.map((item) => item.copyWith()).toList();
  }

  void _syncForeshadowControllers() {
    final item = _selectedForeshadow;
    if (item == null) {
      if (foreshadowTitleController.text.isNotEmpty) {
        foreshadowTitleController.text = "";
      }
      if (foreshadowNoteController.text.isNotEmpty) {
        foreshadowNoteController.text = "";
      }
      return;
    }
    if (foreshadowTitleController.text != item.title) {
      foreshadowTitleController.text = item.title;
    }
    if (foreshadowNoteController.text != item.note) {
      foreshadowNoteController.text = item.note;
    }
  }

  void _syncUpdatePlanControllers() {
    final item = _selectedUpdatePlan;
    if (item == null) {
      if (updatePlanTitleController.text.isNotEmpty) {
        updatePlanTitleController.text = "";
      }
      if (updatePlanNoteController.text.isNotEmpty) {
        updatePlanNoteController.text = "";
      }
      return;
    }
    if (updatePlanTitleController.text != item.title) {
      updatePlanTitleController.text = item.title;
    }
    if (updatePlanNoteController.text != item.note) {
      updatePlanNoteController.text = item.note;
    }
  }

  void _syncInspirationControllers() {
    final item = _selectedInspiration;
    if (item == null) {
      if (inspirationTitleController.text.isNotEmpty) {
        inspirationTitleController.text = "";
      }
      if (inspirationContentController.text.isNotEmpty) {
        inspirationContentController.text = "";
      }
      return;
    }
    if (inspirationTitleController.text != item.title) {
      inspirationTitleController.text = item.title;
    }
    if (inspirationContentController.text != item.content) {
      inspirationContentController.text = item.content;
    }
  }

  void _onForeshadowTitleChanged() {
    final item = _selectedForeshadow;
    if (item == null) return;
    if (item.title != foreshadowTitleController.text) {
      setState(() {
        item.title = foreshadowTitleController.text;
      });
      _notifyProjectChanged();
    }
  }

  void _onForeshadowNoteChanged() {
    final item = _selectedForeshadow;
    if (item == null) return;
    if (item.note != foreshadowNoteController.text) {
      item.note = foreshadowNoteController.text;
      _notifyProjectChanged();
    }
  }

  void _onUpdatePlanTitleChanged() {
    final item = _selectedUpdatePlan;
    if (item == null) return;
    if (item.title != updatePlanTitleController.text) {
      setState(() {
        item.title = updatePlanTitleController.text;
      });
      _notifyProjectChanged();
    }
  }

  void _onUpdatePlanNoteChanged() {
    final item = _selectedUpdatePlan;
    if (item == null) return;
    if (item.note != updatePlanNoteController.text) {
      item.note = updatePlanNoteController.text;
      _notifyProjectChanged();
    }
  }

  void _onInspirationTitleChanged() {
    final item = _selectedInspiration;
    if (item == null) return;
    if (item.title != inspirationTitleController.text) {
      setState(() {
        item.title = inspirationTitleController.text;
      });
      _saveInspirationToDisk();
    }
  }

  void _onInspirationContentChanged() {
    final item = _selectedInspiration;
    if (item == null) return;
    if (item.content != inspirationContentController.text) {
      item.content = inspirationContentController.text;
      _saveInspirationToDisk();
    }
  }

  void _addForeshadow(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      final item = ForeshadowItem(title: trimmed);
      _foreshadowItems.add(item);
      selectedForeshadowId = item.id;
      _syncForeshadowControllers();
    });
    _notifyProjectChanged();
  }

  void _deleteForeshadow(String id) {
    final index = _foreshadowItems.indexWhere((e) => e.id == id);
    if (index == -1) return;
    setState(() {
      _foreshadowItems.removeAt(index);
      if (selectedForeshadowId == id) {
        selectedForeshadowId = null;
        _syncForeshadowControllers();
      }
    });
    _notifyProjectChanged();
  }

  void _toggleForeshadowRevealed(ForeshadowItem item, bool value) {
    setState(() {
      item.isRevealed = value;
    });
    _notifyProjectChanged();
  }

  bool _canAcceptForeshadowDrop(
    _ForeshadowDragData data,
    ForeshadowItem target,
    DropPosition pos,
  ) {
    if (data.id == target.id) return false;
    return pos != DropPosition.child;
  }

  void _reorderForeshadowItems(
    String draggedId,
    String targetId,
    bool isBefore,
  ) {
    final draggedIndex = _foreshadowItems.indexWhere(
      (e) => e.id == draggedId,
    );
    final targetIndex = _foreshadowItems.indexWhere(
      (e) => e.id == targetId,
    );
    if (draggedIndex == -1 || targetIndex == -1) return;

    final draggedItem = _foreshadowItems.removeAt(draggedIndex);
    var adjustedTarget = targetIndex;
    if (draggedIndex < targetIndex) {
      adjustedTarget -= 1;
    }
    final insertIndex = isBefore ? adjustedTarget : adjustedTarget + 1;
    _foreshadowItems.insert(insertIndex, draggedItem);
  }

  void _handleForeshadowDrop(
    _ForeshadowDragData data,
    ForeshadowItem target,
    DropPosition pos,
  ) {
    if (!_canAcceptForeshadowDrop(data, target, pos)) return;

    setState(() {
      _reorderForeshadowItems(data.id, target.id, pos == DropPosition.before);
      selectedForeshadowId = data.id;
    });
    _notifyProjectChanged();
  }

  void _addUpdatePlan(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      final item = UpdatePlanItem(title: trimmed);
      _updatePlanItems.add(item);
      selectedUpdatePlanId = item.id;
      _syncUpdatePlanControllers();
    });
    _notifyProjectChanged();
  }

  void _deleteUpdatePlan(String id) {
    final index = _updatePlanItems.indexWhere((e) => e.id == id);
    if (index == -1) return;
    setState(() {
      _updatePlanItems.removeAt(index);
      if (selectedUpdatePlanId == id) {
        selectedUpdatePlanId = null;
        _syncUpdatePlanControllers();
      }
    });
    _notifyProjectChanged();
  }

  void _toggleUpdatePlanDone(UpdatePlanItem item, bool value) {
    setState(() {
      item.isDone = value;
    });
    _notifyProjectChanged();
  }

  bool _canAcceptUpdatePlanDrop(
    _UpdatePlanDragData data,
    UpdatePlanItem target,
    DropPosition pos,
  ) {
    if (data.id == target.id) return false;
    return pos != DropPosition.child;
  }

  void _reorderUpdatePlanItems(
    String draggedId,
    String targetId,
    bool isBefore,
  ) {
    final draggedIndex = _updatePlanItems.indexWhere(
      (e) => e.id == draggedId,
    );
    final targetIndex = _updatePlanItems.indexWhere(
      (e) => e.id == targetId,
    );
    if (draggedIndex == -1 || targetIndex == -1) return;

    final draggedItem = _updatePlanItems.removeAt(draggedIndex);
    var adjustedTarget = targetIndex;
    if (draggedIndex < targetIndex) {
      adjustedTarget -= 1;
    }
    final insertIndex = isBefore ? adjustedTarget : adjustedTarget + 1;
    _updatePlanItems.insert(insertIndex, draggedItem);
  }

  void _handleUpdatePlanDrop(
    _UpdatePlanDragData data,
    UpdatePlanItem target,
    DropPosition pos,
  ) {
    if (!_canAcceptUpdatePlanDrop(data, target, pos)) return;

    setState(() {
      _reorderUpdatePlanItems(data.id, target.id, pos == DropPosition.before);
      selectedUpdatePlanId = data.id;
    });
    _notifyProjectChanged();
  }

  Future<String> _getDataDirectoryPath() async {
    final appDir = await getApplicationSupportDirectory();
    final dataDir = Directory("${appDir.path}/Data");
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir.path;
  }

  Future<String> get _inspirationFilePath async {
    final dataPath = await _getDataDirectoryPath();
    return "$dataPath/InspirationNotes.json";
  }

  Future<void> _loadInspirationFromDisk() async {
    try {
      final filePath = await _inspirationFilePath;
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _isLoadingInspiration = false;
          });
        }
        return;
      }

      final content = await file.readAsString();
      final jsonData = jsonDecode(content) as Map<String, dynamic>;
      final foldersRaw = (jsonData["folders"] as List<dynamic>?) ?? [];
      final notesRaw = (jsonData["notes"] as List<dynamic>?) ?? [];
      final rootOrderRaw = (jsonData["rootOrder"] as List<dynamic>?) ?? [];

      final loadedFolders = foldersRaw
          .map((e) => InspirationFolder.fromJson(e as Map<String, dynamic>))
          .toList();
      final loadedNotes = notesRaw
          .map((e) => InspirationNote.fromJson(e as Map<String, dynamic>))
          .toList();
      final loadedRootOrder = rootOrderRaw
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        inspirationFolders = loadedFolders;
        inspirationNotes = loadedNotes;
        _rootLayerOrder = loadedRootOrder;
        _ensureRootLayerOrderIntegrity();
        _isLoadingInspiration = false;
      });
    } catch (e) {
      _log.warning("讀取靈感筆記失敗: $e");
      if (!mounted) return;
      setState(() {
        _isLoadingInspiration = false;
      });
    }
  }

  Future<void> _saveInspirationToDisk() async {
    try {
      final payload = {
        "folders": inspirationFolders.map((e) => e.toJson()).toList(),
        "notes": inspirationNotes.map((e) => e.toJson()).toList(),
        "rootOrder": _rootLayerOrder,
      };
      final filePath = await _inspirationFilePath;
      final file = File(filePath);
      await file.writeAsString(jsonEncode(payload));
    } catch (e) {
      _log.warning("儲存靈感筆記失敗: $e");
    }
  }

  void _addInspirationFolder(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      final folder = InspirationFolder(name: trimmed);
      inspirationFolders.add(folder);
      _rootLayerOrder.add(_folderRootKey(folder.id));
      _ensureRootLayerOrderIntegrity();
      selectedFolderId = folder.id;
    });
    _saveInspirationToDisk();
  }

  void _deleteInspirationFolder(String folderId) {
    final folderIndex = inspirationFolders.indexWhere((f) => f.id == folderId);
    if (folderIndex == -1) return;
    setState(() {
      final folderKey = _folderRootKey(folderId);
      final folderOrderIndex = _rootLayerOrder.indexOf(folderKey);
      inspirationFolders.removeAt(folderIndex);
      _rootLayerOrder.remove(folderKey);
      collapsedFolderIds.remove(folderId);

      int insertIndex = folderOrderIndex == -1
          ? _rootLayerOrder.length
          : folderOrderIndex;
      for (final note in inspirationNotes) {
        if (note.folderId == folderId) {
          note.folderId = null;
          final key = _noteRootKey(note.id);
          _rootLayerOrder.remove(key);
          _rootLayerOrder.insert(insertIndex, key);
          insertIndex++;
        }
      }
      _ensureRootLayerOrderIntegrity();
      if (selectedFolderId == folderId) {
        selectedFolderId = null;
      }
    });
    _saveInspirationToDisk();
  }

  void _addInspirationNote(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      final note = InspirationNote(title: trimmed, folderId: selectedFolderId);
      inspirationNotes.add(note);
      if (note.folderId == null) {
        _rootLayerOrder.add(_noteRootKey(note.id));
      }
      _ensureRootLayerOrderIntegrity();
      selectedInspirationId = note.id;
      _syncInspirationControllers();
    });
    _saveInspirationToDisk();
  }

  void _deleteInspirationNote(String noteId) {
    final noteIndex = inspirationNotes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;
    setState(() {
      inspirationNotes.removeAt(noteIndex);
      _rootLayerOrder.remove(_noteRootKey(noteId));
      _ensureRootLayerOrderIntegrity();
      if (selectedInspirationId == noteId) {
        selectedInspirationId = null;
        _syncInspirationControllers();
      }
    });
    _saveInspirationToDisk();
  }

  void _toggleFolderCollapsed(String folderId) {
    setState(() {
      if (collapsedFolderIds.contains(folderId)) {
        collapsedFolderIds.remove(folderId);
      } else {
        collapsedFolderIds.add(folderId);
      }
    });
  }

  List<_InspirationLayerEntry> _buildInspirationLayerEntries() {
    final entries = <_InspirationLayerEntry>[];
    final rootDepth = _showRootDirectory ? 1 : 0;

    final folderMap = <String, InspirationFolder>{
      for (final folder in inspirationFolders) folder.id: folder,
    };
    final rootNoteMap = <String, InspirationNote>{
      for (final note in inspirationNotes.where((n) => n.folderId == null))
        note.id: note,
    };

    for (final key in _rootLayerOrder) {
      if (key.startsWith("F:")) {
        final folderId = _extractRootId(key);
        final folder = folderMap[folderId];
        if (folder == null) continue;

        final noteCount = inspirationNotes
            .where((n) => n.folderId == folder.id)
            .length;
        entries.add(
          _InspirationLayerEntry.folder(
            folder: folder,
            noteCount: noteCount,
            depth: 0,
          ),
        );

        if (!collapsedFolderIds.contains(folder.id)) {
          for (final note in inspirationNotes.where(
            (n) => n.folderId == folder.id,
          )) {
            entries.add(
              _InspirationLayerEntry.note(
                note: note,
                depth: 1,
                folderContextId: folder.id,
              ),
            );
          }
        }
      } else if (key.startsWith("N:")) {
        final noteId = _extractRootId(key);
        final note = rootNoteMap[noteId];
        if (note == null) continue;

        entries.add(
          _InspirationLayerEntry.note(
            note: note,
            depth: rootDepth,
            folderContextId: null,
          ),
        );
      }
    }

    return entries;
  }

  bool _canAcceptInspirationDrop(
    _InspirationDragData data,
    _InspirationLayerEntry target,
    DropPosition pos,
  ) {
    if (data.nodeKey == target.nodeKey) return false;

    if (data.type == _InspirationLayerType.folder) {
      if (pos == DropPosition.child) return false;
      if (target.type == _InspirationLayerType.folder) return true;
      if (target.type == _InspirationLayerType.note) {
        return target.folderContextId == null;
      }
      return false;
    }

    if (data.type == _InspirationLayerType.note) {
      if (target.type == _InspirationLayerType.note) {
        return pos != DropPosition.child;
      }
      if (target.type == _InspirationLayerType.folder) {
        return true;
      }
    }

    return false;
  }

  void _moveFolderBeforeAfter(
    String draggedFolderId,
    String targetFolderId,
    bool isBefore,
  ) {
    _moveRootLayerKeyBeforeAfter(
      _folderRootKey(draggedFolderId),
      _folderRootKey(targetFolderId),
      isBefore,
    );
  }

  void _moveNoteBeforeAfter(
    String draggedNoteId,
    String targetNoteId,
    bool isBefore,
  ) {
    final draggedIndex = inspirationNotes.indexWhere(
      (n) => n.id == draggedNoteId,
    );
    final targetIndex = inspirationNotes.indexWhere(
      (n) => n.id == targetNoteId,
    );
    if (draggedIndex == -1 || targetIndex == -1) return;

    final target = inspirationNotes[targetIndex];
    final dragged = inspirationNotes.removeAt(draggedIndex);
    dragged.folderId = target.folderId;

    if (target.folderId == null) {
      _moveRootLayerKeyBeforeAfter(
        _noteRootKey(draggedNoteId),
        _noteRootKey(targetNoteId),
        isBefore,
      );
    } else {
      _rootLayerOrder.remove(_noteRootKey(draggedNoteId));
    }

    var adjustedTarget = targetIndex;
    if (draggedIndex < targetIndex) {
      adjustedTarget -= 1;
    }
    final insertIndex = isBefore ? adjustedTarget : adjustedTarget + 1;
    inspirationNotes.insert(insertIndex, dragged);
  }

  void _moveNoteToFolder(String noteId, String? folderId) {
    final noteIndex = inspirationNotes.indexWhere((n) => n.id == noteId);
    if (noteIndex == -1) return;

    final note = inspirationNotes.removeAt(noteIndex);
    note.folderId = folderId;

    if (folderId == null) {
      final key = _noteRootKey(note.id);
      if (!_rootLayerOrder.contains(key)) {
        _rootLayerOrder.add(key);
      }
    } else {
      _rootLayerOrder.remove(_noteRootKey(note.id));
    }

    final lastIndexInTarget = inspirationNotes.lastIndexWhere(
      (n) => n.folderId == folderId,
    );
    if (lastIndexInTarget == -1) {
      inspirationNotes.add(note);
    } else {
      inspirationNotes.insert(lastIndexInTarget + 1, note);
    }
  }

  void _moveNoteOutByFolderAnchor(
    String noteId,
    String targetFolderId,
    bool isBefore,
  ) {
    _moveNoteToFolder(noteId, null);
    _moveRootLayerKeyBeforeAfter(
      _noteRootKey(noteId),
      _folderRootKey(targetFolderId),
      isBefore,
    );
  }

  void _handleInspirationDrop(
    _InspirationDragData data,
    _InspirationLayerEntry target,
    DropPosition pos,
  ) {
    if (!_canAcceptInspirationDrop(data, target, pos)) return;

    setState(() {
      if (data.type == _InspirationLayerType.folder &&
          target.type == _InspirationLayerType.folder) {
        _moveFolderBeforeAfter(data.id, target.id, pos == DropPosition.before);
        selectedFolderId = data.id;
        selectedInspirationId = null;
      } else if (data.type == _InspirationLayerType.folder &&
          target.type == _InspirationLayerType.note &&
          target.folderContextId == null) {
        _moveRootLayerKeyBeforeAfter(
          _folderRootKey(data.id),
          _noteRootKey(target.id),
          pos == DropPosition.before,
        );
        selectedFolderId = data.id;
        selectedInspirationId = null;
      } else if (data.type == _InspirationLayerType.note) {
        if (target.type == _InspirationLayerType.note) {
          _moveNoteBeforeAfter(data.id, target.id, pos == DropPosition.before);
          selectedInspirationId = data.id;
        } else if (target.type == _InspirationLayerType.folder) {
          if (pos == DropPosition.child) {
            _moveNoteToFolder(data.id, target.id);
            selectedFolderId = target.id;
          } else {
            // 丟到資料夾上/下區域時，視為移出資料夾到根層並排序。
            _moveNoteOutByFolderAnchor(
              data.id,
              target.id,
              pos == DropPosition.before,
            );
            selectedFolderId = null;
          }
          selectedInspirationId = data.id;
        }
        _syncInspirationControllers();
      }

      _ensureRootLayerOrderIntegrity();
    });
    _saveInspirationToDisk();
  }

  Widget _buildForeshadowSection() {
    final selectedItem = _selectedForeshadow;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MediumTitle(icon: Icons.list_alt_outlined, text: "伏筆列表"),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 180, maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
              child: _foreshadowItems.isEmpty
                  ? const Center(child: Text("尚無伏筆，請新增項目"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _foreshadowItems.length,
                      itemBuilder: (context, index) {
                        final item = _foreshadowItems[index];
                        final isSelected = item.id == selectedForeshadowId;
                        return DraggableCardNode<_ForeshadowDragData>(
                          key: ValueKey("foreshadow:${item.id}"),
                          dragData: _ForeshadowDragData(id: item.id),
                          nodeId: "foreshadow:${item.id}",
                          nodeType: NodeType.item,
                          leading: Icon(
                            item.isRevealed
                                ? Icons.visibility
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            item.title.isEmpty ? "（未命名）" : item.title,
                            style: TextStyle(
                              decoration: item.isRevealed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          subtitle: item.note.isEmpty
                              ? null
                              : Text(
                                  item.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: item.isRevealed,
                                onChanged: (value) {
                                  _toggleForeshadowRevealed(
                                    item,
                                    value ?? false,
                                  );
                                },
                              ),
                              IconButton(
                                onPressed: () => _deleteForeshadow(item.id),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                          isSelected: isSelected,
                          onClicked: () {
                            setState(() {
                              selectedForeshadowId = item.id;
                              _syncForeshadowControllers();
                            });
                          },
                          isDragging: _isForeshadowDragging,
                          isThisDragging: _draggingForeshadowId == item.id,
                          isDragForbidden: false,
                          onDragStarted: () {
                            setState(() {
                              _isForeshadowDragging = true;
                              _draggingForeshadowId = item.id;
                            });
                          },
                          onDragEnd: () {
                            setState(() {
                              _isForeshadowDragging = false;
                              _draggingForeshadowId = null;
                            });
                          },
                          getDropZoneSize: (pos) {
                            if (pos == DropPosition.child) return 0.0;
                            return 0.5;
                          },
                          onWillAccept: (data, pos) {
                            return _canAcceptForeshadowDrop(data, item, pos);
                          },
                          onAccept: (data, pos) {
                            _handleForeshadowDrop(data, item, pos);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            AddItemInput(title: "新增伏筆", onAdd: _addForeshadow),
            const SizedBox(height: 12),
            if (selectedItem == null)
              const Text("請選擇一個伏筆進行編輯")
            else
              Column(
                children: [
                  TextField(
                    controller: foreshadowTitleController,
                    decoration: const InputDecoration(
                      labelText: "伏筆名稱",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: foreshadowNoteController,
                    decoration: const InputDecoration(
                      labelText: "說明",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text("已揭露"),
                    contentPadding: EdgeInsets.zero,
                    value: selectedItem.isRevealed,
                    onChanged: (value) {
                      _toggleForeshadowRevealed(selectedItem, value);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatePlanSection() {
    final selectedItem = _selectedUpdatePlan;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MediumTitle(icon: Icons.note, text: "更新計畫"),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(minHeight: 180, maxHeight: 300),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
              child: _updatePlanItems.isEmpty
                  ? const Center(child: Text("尚無更新計畫，請新增項目"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _updatePlanItems.length,
                      itemBuilder: (context, index) {
                        final item = _updatePlanItems[index];
                        final isSelected = item.id == selectedUpdatePlanId;
                        return DraggableCardNode<_UpdatePlanDragData>(
                          key: ValueKey("update-plan:${item.id}"),
                          dragData: _UpdatePlanDragData(id: item.id),
                          nodeId: "update-plan:${item.id}",
                          nodeType: NodeType.item,
                          leading: Icon(
                            item.isDone
                                ? Icons.task_alt_outlined
                                : Icons.pending_actions_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            item.title.isEmpty ? "（未命名）" : item.title,
                            style: TextStyle(
                              decoration: item.isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          subtitle: item.note.isEmpty
                              ? null
                              : Text(
                                  item.note,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: item.isDone,
                                onChanged: (value) {
                                  _toggleUpdatePlanDone(item, value ?? false);
                                },
                              ),
                              IconButton(
                                onPressed: () => _deleteUpdatePlan(item.id),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                          isSelected: isSelected,
                          onClicked: () {
                            setState(() {
                              selectedUpdatePlanId = item.id;
                              _syncUpdatePlanControllers();
                            });
                          },
                          isDragging: _isUpdatePlanDragging,
                          isThisDragging: _draggingUpdatePlanId == item.id,
                          isDragForbidden: false,
                          onDragStarted: () {
                            setState(() {
                              _isUpdatePlanDragging = true;
                              _draggingUpdatePlanId = item.id;
                            });
                          },
                          onDragEnd: () {
                            setState(() {
                              _isUpdatePlanDragging = false;
                              _draggingUpdatePlanId = null;
                            });
                          },
                          getDropZoneSize: (pos) {
                            if (pos == DropPosition.child) return 0.0;
                            return 0.5;
                          },
                          onWillAccept: (data, pos) {
                            return _canAcceptUpdatePlanDrop(data, item, pos);
                          },
                          onAccept: (data, pos) {
                            _handleUpdatePlanDrop(data, item, pos);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            AddItemInput(title: "新增更新計畫", onAdd: _addUpdatePlan),
            const SizedBox(height: 12),
            if (selectedItem == null)
              const Text("請選擇一個更新計畫進行編輯")
            else
              Column(
                children: [
                  TextField(
                    controller: updatePlanTitleController,
                    decoration: const InputDecoration(
                      labelText: "計畫名稱",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: updatePlanNoteController,
                    decoration: const InputDecoration(
                      labelText: "說明",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text("已完成"),
                    contentPadding: EdgeInsets.zero,
                    value: selectedItem.isDone,
                    onChanged: (value) {
                      _toggleUpdatePlanDone(selectedItem, value);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspirationLayerList() {
    final entries = _buildInspirationLayerEntries();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 220, maxHeight: 420),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
          ),
          child: inspirationFolders.isEmpty && inspirationNotes.isEmpty
              ? const Center(child: Text("尚無靈感，請新增資料夾或靈感"))
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    if (_showRootDirectory)
                      ListTile(
                        selected:
                            selectedFolderId == null &&
                            selectedInspirationId == null,
                        leading: const Icon(Icons.home_outlined),
                        title: const Text("根目錄"),
                        onTap: () {
                          setState(() {
                            selectedFolderId = null;
                            selectedInspirationId = null;
                            _syncInspirationControllers();
                          });
                        },
                      ),
                    ...entries.map((entry) {
                      final isFolder =
                          entry.type == _InspirationLayerType.folder;
                      final isSelected = isFolder
                          ? (selectedFolderId == entry.id &&
                                selectedInspirationId == null)
                          : selectedInspirationId == entry.id;
                      final isCollapsed =
                          isFolder && collapsedFolderIds.contains(entry.id);

                      return DraggableCardNode<_InspirationDragData>(
                        key: ValueKey(entry.nodeKey),
                        dragData: _InspirationDragData(
                          id: entry.id,
                          type: entry.type,
                        ),
                        nodeId: entry.nodeKey,
                        nodeType: isFolder ? NodeType.folder : NodeType.item,
                        leading: Icon(
                          isFolder
                              ? (isCollapsed
                                    ? Icons.folder_outlined
                                    : Icons.folder_open_outlined)
                              : Icons.lightbulb_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        title: Text(entry.title),
                        subtitle: entry.subtitle == null
                            ? null
                            : Text(
                                entry.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isFolder)
                              IconButton(
                                onPressed: () =>
                                    _toggleFolderCollapsed(entry.id),
                                tooltip: isCollapsed ? "展開" : "收合",
                                icon: Icon(
                                  isCollapsed
                                      ? Icons.chevron_right
                                      : Icons.expand_more,
                                ),
                              ),
                            IconButton(
                              onPressed: () {
                                if (isFolder) {
                                  _deleteInspirationFolder(entry.id);
                                } else {
                                  _deleteInspirationNote(entry.id);
                                }
                              },
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                        isSelected: isSelected,
                        onClicked: () {
                          setState(() {
                            if (isFolder) {
                              selectedFolderId = entry.id;
                              selectedInspirationId = null;
                            } else {
                              selectedInspirationId = entry.id;
                              selectedFolderId = entry.folderContextId;
                              _syncInspirationControllers();
                            }
                          });
                        },
                        isDragging: _isInspirationDragging,
                        isThisDragging:
                            _draggingInspirationNodeKey == entry.nodeKey,
                        isDragForbidden: false,
                        onDragStarted: () {
                          setState(() {
                            _isInspirationDragging = true;
                            _draggingInspirationNodeKey = entry.nodeKey;
                          });
                        },
                        onDragEnd: () {
                          setState(() {
                            _isInspirationDragging = false;
                            _draggingInspirationNodeKey = null;
                          });
                        },
                        getDropZoneSize: (pos) {
                          if (isFolder) {
                            if (pos == DropPosition.child) return 0.34;
                            return 0.33;
                          }
                          return pos == DropPosition.child ? 0.0 : 0.5;
                        },
                        onWillAccept: (data, pos) {
                          return _canAcceptInspirationDrop(data, entry, pos);
                        },
                        onAccept: (data, pos) {
                          _handleInspirationDrop(data, entry, pos);
                        },
                        indent: entry.depth * 28.0,
                      );
                    }),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        AddItemInput(title: "資料夾", onAdd: _addInspirationFolder),
        const SizedBox(height: 8),
        AddItemInput(title: "靈感", onAdd: _addInspirationNote),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildInspirationEditorPanel() {
    final selected = _selectedInspiration;
    if (selected == null) {
      return const Text("請選擇一則靈感進行編輯");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: inspirationTitleController,
          decoration: const InputDecoration(
            labelText: "靈感標題",
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: inspirationContentController,
          decoration: const InputDecoration(
            labelText: "內容",
            border: OutlineInputBorder(),
            isDense: true,
          ),
          minLines: 4,
          maxLines: 8,
        ),
      ],
    );
  }

  Widget _buildInspirationSection() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MediumTitle(icon: Icons.book_outlined, text: "靈感筆記"),
            const SizedBox(height: 12),
            if (_isLoadingInspiration)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildInspirationLayerList(),
              const SizedBox(height: 12),
              _buildInspirationEditorPanel(),
            ],
          ],
        ),
      ),
    );
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: LargeTitle(icon: Icons.assessment, text: "計畫規劃"),
            ),

            const SizedBox(height: 32),
            _buildForeshadowSection(),
            const SizedBox(height: 12),
            _buildUpdatePlanSection(),
            const SizedBox(height: 12),
            _buildInspirationSection(),
          ],
        ),
      ),
    );
  }
}
