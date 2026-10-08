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
import "package:flutter_riverpod/flutter_riverpod.dart";
import "dart:async";
import "dart:convert";
import "dart:io";
import "package:path_provider/path_provider.dart";
import "package:uuid/uuid.dart";
import "package:xml/xml.dart" as xml;
import "../models/codecs/xml_text_codec.dart";
import "../bin/ui_library.dart";
import "package:logging/logging.dart";
import "../models/plan_data.dart";
import "../presentation/providers/project_state_providers.dart";
import "../utils/latest_wins_writer.dart";

export "../models/plan_data.dart";

final _log = Logger("PlanView");

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
  String? parentId;
  final List<String> childOrder;

  InspirationFolder({
    String? id,
    this.name = "",
    this.parentId,
    List<String>? childOrder,
  }) : id = id ?? const Uuid().v4(),
       childOrder = List<String>.of(childOrder ?? const []);

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "parentId": parentId,
    "childOrder": List<String>.of(childOrder),
  };

  factory InspirationFolder.fromJson(Map<String, dynamic> json) {
    return InspirationFolder(
      id: json["id"] as String?,
      name: json["name"] as String? ?? "",
      parentId: json["parentId"] as String?,
      childOrder: (json["childOrder"] as List<dynamic>?)?.cast<String>(),
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
      folderContextId: folder.parentId,
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

class PlanCodec {
  static void _writeTextElement(
    xml.XmlBuilder builder,
    String name,
    String value,
  ) {
    XmlTextCodec.writeTextElement(builder, name, value);
  }

  static String _readElementText(xml.XmlElement? element) {
    return XmlTextCodec.readElementText(element);
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
      return typeElement == null ? null : loadElement(typeElement);
    } catch (e) {
      _log.warning("Error parsing PlanSettings XML: $e");
      return null;
    }
  }

  // 自已解析的 Type 區塊載入，避免專案載入時重複序列化與解析。
  static PlanProjectData? loadElement(xml.XmlElement typeElement) {
    try {
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
      _log.warning("Error parsing PlanSettings XML element: $e");
      return null;
    }
  }
}

enum PlanSelectionTarget { foreshadow, updatePlan }

class PlanView extends ConsumerStatefulWidget {
  final String? initialTargetId;
  final PlanSelectionTarget? initialTargetKind;
  final int selectionRequestId;

  const PlanView({
    super.key,
    this.initialTargetId,
    this.initialTargetKind,
    this.selectionRequestId = 0,
  });

  @override
  ConsumerState<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends ConsumerState<PlanView> {
  bool _registeredProviderListeners = false;
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
  List<String> _rootLayerOrder = [];

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
  final FocusNode _inspirationTitleFocusNode = FocusNode();
  final FocusNode _inspirationContentFocusNode = FocusNode();
  late final Future<File> _inspirationFile;
  late final LatestWinsWriter _inspirationWriter;

  List<InspirationFolder> inspirationFolders = [];
  List<InspirationNote> inspirationNotes = [];
  bool _isLoadingInspiration = true;

  @override
  void initState() {
    super.initState();

    _inspirationFile = _resolveInspirationFile();
    _inspirationWriter = LatestWinsWriter(
      write: (content) async {
        try {
          await writeTextAtomically(await _inspirationFile, content);
        } catch (error) {
          _log.warning("儲存靈感筆記失敗: $error");
        }
      },
    );

    foreshadowTitleController.addListener(_onForeshadowTitleChanged);
    foreshadowNoteController.addListener(_onForeshadowNoteChanged);
    updatePlanTitleController.addListener(_onUpdatePlanTitleChanged);
    updatePlanNoteController.addListener(_onUpdatePlanNoteChanged);
    inspirationTitleController.addListener(_onInspirationTitleChanged);
    inspirationContentController.addListener(_onInspirationContentChanged);
    _inspirationTitleFocusNode.addListener(_flushInspirationOnBlur);
    _inspirationContentFocusNode.addListener(_flushInspirationOnBlur);

    _loadInspirationFromDisk();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyRequestedTarget();
    });
  }

  @override
  void didUpdateWidget(covariant PlanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionRequestId != widget.selectionRequestId ||
        oldWidget.initialTargetId != widget.initialTargetId ||
        oldWidget.initialTargetKind != widget.initialTargetKind) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyRequestedTarget();
      });
    }
  }

  void _applyRequestedTarget() {
    final id = widget.initialTargetId;
    final kind = widget.initialTargetKind;
    if (id == null || kind == null) return;
    switch (kind) {
      case PlanSelectionTarget.foreshadow:
        if (!_foreshadowItems.any((item) => item.id == id)) return;
        setState(() {
          selectedForeshadowId = id;
          selectedUpdatePlanId = null;
          _syncForeshadowControllers();
        });
      case PlanSelectionTarget.updatePlan:
        if (!_updatePlanItems.any((item) => item.id == id)) return;
        setState(() {
          selectedUpdatePlanId = id;
          selectedForeshadowId = null;
          _syncUpdatePlanControllers();
        });
    }
  }

  @override
  void dispose() {
    _scheduleInspirationSave(immediate: true);
    unawaited(_inspirationWriter.close());
    foreshadowTitleController.removeListener(_onForeshadowTitleChanged);
    foreshadowNoteController.removeListener(_onForeshadowNoteChanged);
    updatePlanTitleController.removeListener(_onUpdatePlanTitleChanged);
    updatePlanNoteController.removeListener(_onUpdatePlanNoteChanged);
    inspirationTitleController.removeListener(_onInspirationTitleChanged);
    inspirationContentController.removeListener(_onInspirationContentChanged);
    _inspirationTitleFocusNode.removeListener(_flushInspirationOnBlur);
    _inspirationContentFocusNode.removeListener(_flushInspirationOnBlur);

    foreshadowTitleController.dispose();
    foreshadowNoteController.dispose();
    updatePlanTitleController.dispose();
    updatePlanNoteController.dispose();
    inspirationTitleController.dispose();
    inspirationContentController.dispose();
    _inspirationTitleFocusNode.dispose();
    _inspirationContentFocusNode.dispose();
    super.dispose();
  }

  List<ForeshadowItem> get _foreshadowItems => ref.read(foreshadowDataProvider);

  List<UpdatePlanItem> get _updatePlanItems => ref.read(updatePlanDataProvider);

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

  InspirationFolder? _findInspirationFolder(String? id) {
    for (final folder in inspirationFolders) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  List<String> _inspirationLayerOrder(String? parentId) =>
      _findInspirationFolder(parentId)?.childOrder ?? _rootLayerOrder;

  bool _isInspirationDescendant(String? folderId, String ancestorId) {
    final visited = <String>{};
    while (folderId != null && visited.add(folderId)) {
      if (folderId == ancestorId) return true;
      folderId = _findInspirationFolder(folderId)?.parentId;
    }
    return false;
  }

  void _ensureRootLayerOrderIntegrity() {
    final folderIds = inspirationFolders.map((folder) => folder.id).toSet();
    for (final folder in inspirationFolders) {
      if (!folderIds.contains(folder.parentId) ||
          _isInspirationDescendant(folder.parentId, folder.id)) {
        folder.parentId = null;
      }
    }
    for (final note in inspirationNotes) {
      if (!folderIds.contains(note.folderId)) note.folderId = null;
    }

    final children = <String?, List<String>>{null: []};
    for (final folder in inspirationFolders) {
      children
          .putIfAbsent(folder.parentId, () => [])
          .add(_folderRootKey(folder.id));
    }
    for (final note in inspirationNotes) {
      children.putIfAbsent(note.folderId, () => []).add(_noteRootKey(note.id));
    }
    for (final parentId in <String?>[null, ...folderIds]) {
      final order = _inspirationLayerOrder(parentId);
      final validKeys = children[parentId] ?? const <String>[];
      final seen = <String>{};
      final retained = order
          .where((key) => validKeys.contains(key) && seen.add(key))
          .toList();
      order
        ..clear()
        ..addAll(retained)
        ..addAll(validKeys.where((key) => seen.add(key)));
    }
  }

  void _clearInspirationSelection() {
    if (selectedFolderId == null && selectedInspirationId == null) return;
    _inspirationTitleFocusNode.unfocus();
    _inspirationContentFocusNode.unfocus();
    setState(() {
      selectedFolderId = null;
      selectedInspirationId = null;
      _syncInspirationControllers();
    });
    unawaited(_inspirationWriter.flush());
  }

  void _emitProjectChanged() {
    // Dirty tracking is driven by provider listeners in coordinator.
  }

  bool _updateForeshadowById(
    String id,
    ForeshadowItem Function(ForeshadowItem current) update,
  ) {
    final didUpdate = ref
        .read(foreshadowDataProvider.notifier)
        .updateForeshadowById(id, update);
    if (didUpdate) {
      _emitProjectChanged();
    }
    return didUpdate;
  }

  bool _updateUpdatePlanById(
    String id,
    UpdatePlanItem Function(UpdatePlanItem current) update,
  ) {
    final didUpdate = ref
        .read(updatePlanDataProvider.notifier)
        .updateUpdatePlanById(id, update);
    if (didUpdate) {
      _emitProjectChanged();
    }
    return didUpdate;
  }

  bool _reorderForeshadowItems(
    String draggedId,
    String targetId,
    bool isBefore,
  ) {
    final didUpdate = ref
        .read(foreshadowDataProvider.notifier)
        .reorderForeshadowByDrop(
          draggedId: draggedId,
          targetId: targetId,
          isBefore: isBefore,
        );
    if (didUpdate) {
      _emitProjectChanged();
    }
    return didUpdate;
  }

  bool _reorderUpdatePlanItems(
    String draggedId,
    String targetId,
    bool isBefore,
  ) {
    final didUpdate = ref
        .read(updatePlanDataProvider.notifier)
        .reorderUpdatePlanByDrop(
          draggedId: draggedId,
          targetId: targetId,
          isBefore: isBefore,
        );
    if (didUpdate) {
      _emitProjectChanged();
    }
    return didUpdate;
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
      _updateForeshadowById(
        item.id,
        (current) => current.copyWith(title: foreshadowTitleController.text),
      );
    }
  }

  void _onForeshadowNoteChanged() {
    final item = _selectedForeshadow;
    if (item == null) return;
    if (item.note != foreshadowNoteController.text) {
      _updateForeshadowById(
        item.id,
        (current) => current.copyWith(note: foreshadowNoteController.text),
      );
    }
  }

  void _onUpdatePlanTitleChanged() {
    final item = _selectedUpdatePlan;
    if (item == null) return;
    if (item.title != updatePlanTitleController.text) {
      _updateUpdatePlanById(
        item.id,
        (current) => current.copyWith(title: updatePlanTitleController.text),
      );
    }
  }

  void _onUpdatePlanNoteChanged() {
    final item = _selectedUpdatePlan;
    if (item == null) return;
    if (item.note != updatePlanNoteController.text) {
      _updateUpdatePlanById(
        item.id,
        (current) => current.copyWith(note: updatePlanNoteController.text),
      );
    }
  }

  void _onInspirationTitleChanged() {
    final item = _selectedInspiration;
    if (item == null) return;
    if (item.title != inspirationTitleController.text) {
      setState(() {
        item.title = inspirationTitleController.text;
      });
      _scheduleInspirationSave();
    }
  }

  void _onInspirationContentChanged() {
    final item = _selectedInspiration;
    if (item == null) return;
    if (item.content != inspirationContentController.text) {
      item.content = inspirationContentController.text;
      _scheduleInspirationSave();
    }
  }

  void _addForeshadow(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final item = ForeshadowItem(title: trimmed);
    ref.read(foreshadowDataProvider.notifier).addForeshadowItem(item);
    setState(() {
      selectedForeshadowId = item.id;
      _syncForeshadowControllers();
    });
    _emitProjectChanged();
  }

  void _deleteForeshadow(String id) {
    final removed = ref
        .read(foreshadowDataProvider.notifier)
        .removeForeshadowById(id);
    if (!removed) return;

    setState(() {
      if (selectedForeshadowId == id) {
        selectedForeshadowId = null;
        _syncForeshadowControllers();
      }
    });
    _emitProjectChanged();
  }

  void _toggleForeshadowRevealed(ForeshadowItem item, bool value) {
    _updateForeshadowById(
      item.id,
      (current) => current.copyWith(isRevealed: value),
    );
  }

  bool _canAcceptForeshadowDrop(
    _ForeshadowDragData data,
    ForeshadowItem target,
    DropPosition pos,
  ) {
    if (data.id == target.id) return false;
    return pos != DropPosition.child;
  }

  void _handleForeshadowDrop(
    _ForeshadowDragData data,
    ForeshadowItem target,
    DropPosition pos,
  ) {
    if (!_canAcceptForeshadowDrop(data, target, pos)) return;

    final didReorder = _reorderForeshadowItems(
      data.id,
      target.id,
      pos == DropPosition.before,
    );
    if (!didReorder) {
      return;
    }

    setState(() {
      selectedForeshadowId = data.id;
    });
  }

  void _addUpdatePlan(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final item = UpdatePlanItem(title: trimmed);
    ref.read(updatePlanDataProvider.notifier).addUpdatePlanItem(item);
    setState(() {
      selectedUpdatePlanId = item.id;
      _syncUpdatePlanControllers();
    });
    _emitProjectChanged();
  }

  void _deleteUpdatePlan(String id) {
    final removed = ref
        .read(updatePlanDataProvider.notifier)
        .removeUpdatePlanById(id);
    if (!removed) return;

    setState(() {
      if (selectedUpdatePlanId == id) {
        selectedUpdatePlanId = null;
        _syncUpdatePlanControllers();
      }
    });
    _emitProjectChanged();
  }

  void _toggleUpdatePlanDone(UpdatePlanItem item, bool value) {
    _updateUpdatePlanById(
      item.id,
      (current) => current.copyWith(isDone: value),
    );
  }

  bool _canAcceptUpdatePlanDrop(
    _UpdatePlanDragData data,
    UpdatePlanItem target,
    DropPosition pos,
  ) {
    if (data.id == target.id) return false;
    return pos != DropPosition.child;
  }

  void _handleUpdatePlanDrop(
    _UpdatePlanDragData data,
    UpdatePlanItem target,
    DropPosition pos,
  ) {
    if (!_canAcceptUpdatePlanDrop(data, target, pos)) return;

    final didReorder = _reorderUpdatePlanItems(
      data.id,
      target.id,
      pos == DropPosition.before,
    );
    if (!didReorder) {
      return;
    }

    setState(() {
      selectedUpdatePlanId = data.id;
    });
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

  Future<File> _resolveInspirationFile() async {
    return File(await _inspirationFilePath);
  }

  Future<void> _loadInspirationFromDisk() async {
    try {
      final file = await _inspirationFile;
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

  String _createInspirationSnapshot() {
    return jsonEncode({
      "folders": inspirationFolders.map((e) => e.toJson()).toList(),
      "notes": inspirationNotes.map((e) => e.toJson()).toList(),
      "rootOrder": List<String>.of(_rootLayerOrder),
    });
  }

  void _scheduleInspirationSave({bool immediate = false}) {
    if (_isLoadingInspiration) {
      return;
    }
    _inspirationWriter.schedule(
      _createInspirationSnapshot,
      immediate: immediate,
    );
  }

  void _flushInspirationOnBlur() {
    if (!_inspirationTitleFocusNode.hasFocus &&
        !_inspirationContentFocusNode.hasFocus) {
      unawaited(_inspirationWriter.flush());
    }
  }

  void _addInspirationFolder(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      final folder = InspirationFolder(
        name: trimmed,
        parentId: selectedFolderId,
      );
      inspirationFolders.add(folder);
      _inspirationLayerOrder(folder.parentId).add(_folderRootKey(folder.id));
      collapsedFolderIds.remove(folder.parentId);
      _ensureRootLayerOrderIntegrity();
      selectedFolderId = folder.id;
      selectedInspirationId = null;
      _syncInspirationControllers();
    });
    _scheduleInspirationSave(immediate: true);
  }

  void _deleteInspirationFolder(String folderId) {
    final folderIndex = inspirationFolders.indexWhere((f) => f.id == folderId);
    if (folderIndex == -1) return;
    setState(() {
      final folder = inspirationFolders[folderIndex];
      final parentOrder = _inspirationLayerOrder(folder.parentId);
      final folderKey = _folderRootKey(folderId);
      final folderOrderIndex = parentOrder.indexOf(folderKey);
      parentOrder.remove(folderKey);
      parentOrder.insertAll(
        folderOrderIndex == -1 ? parentOrder.length : folderOrderIndex,
        folder.childOrder,
      );
      inspirationFolders.removeAt(folderIndex);
      collapsedFolderIds.remove(folderId);
      for (final child in inspirationFolders) {
        if (child.parentId == folderId) child.parentId = folder.parentId;
      }
      for (final note in inspirationNotes) {
        if (note.folderId == folderId) {
          note.folderId = folder.parentId;
        }
      }
      _ensureRootLayerOrderIntegrity();
      if (selectedFolderId == folderId) {
        selectedFolderId = folder.parentId;
      }
    });
    _scheduleInspirationSave(immediate: true);
  }

  void _addInspirationNote(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      final note = InspirationNote(title: trimmed, folderId: selectedFolderId);
      inspirationNotes.add(note);
      _inspirationLayerOrder(note.folderId).add(_noteRootKey(note.id));
      collapsedFolderIds.remove(note.folderId);
      _ensureRootLayerOrderIntegrity();
      selectedInspirationId = note.id;
      _syncInspirationControllers();
    });
    _scheduleInspirationSave(immediate: true);
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
    _scheduleInspirationSave(immediate: true);
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
    final folderMap = {
      for (final folder in inspirationFolders) folder.id: folder,
    };
    final noteMap = {for (final note in inspirationNotes) note.id: note};
    final visited = <String>{};

    void appendChildren(List<String> order, int depth) {
      for (final key in order) {
        if (!visited.add(key)) continue;
        final id = _extractRootId(key);
        if (key.startsWith("F:")) {
          final folder = folderMap[id];
          if (folder == null) continue;
          entries.add(
            _InspirationLayerEntry.folder(
              folder: folder,
              noteCount: inspirationNotes.where((n) => n.folderId == id).length,
              depth: depth,
            ),
          );
          if (!collapsedFolderIds.contains(id)) {
            appendChildren(folder.childOrder, depth + 1);
          }
        } else if (key.startsWith("N:")) {
          final note = noteMap[id];
          if (note == null) continue;
          entries.add(
            _InspirationLayerEntry.note(
              note: note,
              depth: depth,
              folderContextId: note.folderId,
            ),
          );
        }
      }
    }

    appendChildren(_rootLayerOrder, 0);
    return entries;
  }

  bool _canAcceptInspirationDrop(
    _InspirationDragData data,
    _InspirationLayerEntry target,
    DropPosition pos,
  ) {
    if (data.nodeKey == target.nodeKey) return false;
    if (pos == DropPosition.child &&
        target.type != _InspirationLayerType.folder) {
      return false;
    }
    final parentId = pos == DropPosition.child
        ? target.id
        : target.folderContextId;
    if (data.type == _InspirationLayerType.folder) {
      return _findInspirationFolder(data.id) != null &&
          !_isInspirationDescendant(parentId, data.id);
    }
    return inspirationNotes.any((note) => note.id == data.id);
  }

  void _handleInspirationDrop(
    _InspirationDragData data,
    _InspirationLayerEntry target,
    DropPosition pos,
  ) {
    if (!_canAcceptInspirationDrop(data, target, pos)) return;
    final parentId = pos == DropPosition.child
        ? target.id
        : target.folderContextId;
    final draggedKey = data.type == _InspirationLayerType.folder
        ? _folderRootKey(data.id)
        : _noteRootKey(data.id);
    final targetKey = target.type == _InspirationLayerType.folder
        ? _folderRootKey(target.id)
        : _noteRootKey(target.id);

    setState(() {
      if (data.type == _InspirationLayerType.folder) {
        final folder = _findInspirationFolder(data.id)!;
        _inspirationLayerOrder(folder.parentId).remove(draggedKey);
        folder.parentId = parentId;
        selectedFolderId = data.id;
        selectedInspirationId = null;
      } else {
        final note = inspirationNotes.firstWhere((note) => note.id == data.id);
        _inspirationLayerOrder(note.folderId).remove(draggedKey);
        note.folderId = parentId;
        selectedFolderId = parentId;
        selectedInspirationId = data.id;
      }
      final order = _inspirationLayerOrder(parentId);
      if (pos == DropPosition.child) {
        order.add(draggedKey);
        collapsedFolderIds.remove(parentId);
      } else {
        final targetIndex = order.indexOf(targetKey);
        order.insert(
          targetIndex == -1
              ? order.length
              : targetIndex + (pos == DropPosition.after ? 1 : 0),
          draggedKey,
        );
      }
      _ensureRootLayerOrderIntegrity();
      _syncInspirationControllers();
    });
    _scheduleInspirationSave(immediate: true);
  }

  Widget _buildForeshadowSection(List<ForeshadowItem> items) {
    final selectedItem = _selectedForeshadow;
    return AppSectionCard(
      padding: EdgeInsets.zero,
      useSectionLayout: false,
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MediumTitle(icon: Icons.list_alt_outlined, text: "伏筆列表"),
            const SizedBox(height: 12),
            CollectionPanel.custom(
              title: "伏筆列表",
              showSectionCard: false,
              minHeight: 180,
              maxHeight: 300,
              content: items.isEmpty
                  ? const AppEmptyState(
                      title: "尚無伏筆",
                      description: "請新增第一個項目",
                      compact: true,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
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
                              ItemActionBar(
                                actions: [
                                  ItemAction.delete(
                                    onPressed: () => _deleteForeshadow(item.id),
                                  ),
                                ],
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
              const AppEmptyState(
                title: "請選擇一個伏筆",
                description: "選取後即可編輯內容",
                icon: Icons.touch_app_outlined,
                compact: true,
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              )
            else
              Column(
                children: [
                  AppTextField(
                    controller: foreshadowTitleController,
                    decoration: const InputDecoration(
                      labelText: "伏筆名稱",
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: foreshadowNoteController,
                    decoration: const InputDecoration(
                      labelText: "說明",
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

  Widget _buildUpdatePlanSection(List<UpdatePlanItem> items) {
    final selectedItem = _selectedUpdatePlan;
    return AppSectionCard(
      padding: EdgeInsets.zero,
      useSectionLayout: false,
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MediumTitle(icon: Icons.note, text: "更新計畫"),
            const SizedBox(height: 12),
            CollectionPanel.custom(
              title: "更新計畫",
              showSectionCard: false,
              minHeight: 180,
              maxHeight: 300,
              content: items.isEmpty
                  ? const AppEmptyState(
                      title: "尚無更新計畫",
                      description: "請新增第一個項目",
                      compact: true,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
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
                              ItemActionBar(
                                actions: [
                                  ItemAction.delete(
                                    onPressed: () => _deleteUpdatePlan(item.id),
                                  ),
                                ],
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
              const AppEmptyState(
                title: "請選擇一個更新計畫",
                description: "選取後即可編輯內容",
                icon: Icons.touch_app_outlined,
                compact: true,
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              )
            else
              Column(
                children: [
                  AppTextField(
                    controller: updatePlanTitleController,
                    decoration: const InputDecoration(
                      labelText: "計畫名稱",
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: updatePlanNoteController,
                    decoration: const InputDecoration(
                      labelText: "說明",
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
        CollectionPanel.custom(
          title: "靈感列表",
          showSectionCard: false,
          minHeight: 220,
          maxHeight: 420,
          content: inspirationFolders.isEmpty && inspirationNotes.isEmpty
              ? const AppEmptyState(
                  title: "尚無靈感",
                  description: "請新增資料夾或靈感",
                  compact: true,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxDepth = entries.fold<int>(
                      0,
                      (depth, entry) =>
                          entry.depth > depth ? entry.depth : depth,
                    );
                    final minimumWidth = 320.0 + maxDepth * 28.0;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: constraints.maxWidth < minimumWidth
                            ? minimumWidth
                            : constraints.maxWidth,
                        child: ListView.builder(
                          key: const ValueKey("inspiration-layer-list"),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          itemCount: entries.length,
                          itemBuilder: (BuildContext context, int index) {
                            final entry = entries[index];
                            final isFolder =
                                entry.type == _InspirationLayerType.folder;
                            final isSelected = isFolder
                                ? (selectedFolderId == entry.id &&
                                      selectedInspirationId == null)
                                : selectedInspirationId == entry.id;
                            final isCollapsed =
                                isFolder &&
                                collapsedFolderIds.contains(entry.id);

                            return DraggableCardNode<_InspirationDragData>(
                              key: ValueKey(entry.nodeKey),
                              dragData: _InspirationDragData(
                                id: entry.id,
                                type: entry.type,
                              ),
                              nodeId: entry.nodeKey,
                              nodeType: isFolder
                                  ? NodeType.folder
                                  : NodeType.item,
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
                                  ItemActionBar(
                                    actions: [
                                      ItemAction.delete(
                                        onPressed: () {
                                          if (isFolder) {
                                            _deleteInspirationFolder(entry.id);
                                          } else {
                                            _deleteInspirationNote(entry.id);
                                          }
                                        },
                                      ),
                                    ],
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
                                  }
                                  _syncInspirationControllers();
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
                                return _canAcceptInspirationDrop(
                                  data,
                                  entry,
                                  pos,
                                );
                              },
                              onAccept: (data, pos) {
                                _handleInspirationDrop(data, entry, pos);
                              },
                              indent: entry.depth * 28.0,
                            );
                          },
                        ),
                      ),
                    );
                  },
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
      return const AppEmptyState(
        title: "請選擇一則靈感",
        description: "選取後即可編輯內容",
        icon: Icons.touch_app_outlined,
        compact: true,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: inspirationTitleController,
          focusNode: _inspirationTitleFocusNode,
          decoration: const InputDecoration(labelText: "靈感標題", isDense: true),
        ),
        const SizedBox(height: 8),
        AppTextField(
          controller: inspirationContentController,
          focusNode: _inspirationContentFocusNode,
          decoration: const InputDecoration(labelText: "內容", isDense: true),
          minLines: 4,
          maxLines: 8,
        ),
      ],
    );
  }

  Widget _buildInspirationSection() {
    return GestureDetector(
      key: const ValueKey("inspiration-section"),
      behavior: HitTestBehavior.opaque,
      onTap: _clearInspirationSelection,
      child: AppSectionCard(
        padding: EdgeInsets.zero,
        useSectionLayout: false,
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
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
      ),
    );
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    final foreshadowItems = ref.watch(foreshadowDataProvider);
    final updatePlanItems = ref.watch(updatePlanDataProvider);

    if (!_registeredProviderListeners) {
      ref.listen<List<ForeshadowItem>>(foreshadowDataProvider, (
        previous,
        next,
      ) {
        if (!mounted) return;
        if (selectedForeshadowId == null) return;
        final exists = next.any((item) => item.id == selectedForeshadowId);
        if (!exists) {
          setState(() {
            selectedForeshadowId = null;
            _syncForeshadowControllers();
          });
        }
      });

      ref.listen<List<UpdatePlanItem>>(updatePlanDataProvider, (
        previous,
        next,
      ) {
        if (!mounted) return;
        if (selectedUpdatePlanId == null) return;
        final exists = next.any((item) => item.id == selectedUpdatePlanId);
        if (!exists) {
          setState(() {
            selectedUpdatePlanId = null;
            _syncUpdatePlanControllers();
          });
        }
      });

      _registeredProviderListeners = true;
    }

    return Scaffold(
      body: AppPageScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: LargeTitle(icon: Icons.assessment, text: "計畫規劃"),
            ),

            const SizedBox(height: 32),
            _buildForeshadowSection(foreshadowItems),
            const SizedBox(height: 12),
            _buildUpdatePlanSection(updatePlanItems),
            const SizedBox(height: 12),
            _buildInspirationSection(),
          ],
        ),
      ),
    );
  }
}
