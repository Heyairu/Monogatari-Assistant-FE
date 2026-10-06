/* **********************************************************
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

import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/gestures.dart" show DragStartBehavior;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:monogatari_assistant/bin/ui_library.dart";

import "../models/character_data.dart";
import "../models/character_snapshot_data.dart";
import "../presentation/providers/character_snapshot_providers.dart";
import "../presentation/providers/project_state_providers.dart";
import "character_relationship_editor.dart";
import "character_relationship_graph_controller.dart";
import "character_relationship_graph_mapper.dart";
import "character_relationship_graph_layout.dart";
import "character_relationship_graph_routing.dart";
import "character_relationship_graph_mutations.dart";
import "character_relationship_operations.dart";
import "character_relationship_resolver.dart";

class CharacterRelationshipGraphView extends ConsumerStatefulWidget {
  final int projectSessionId;
  final ValueChanged<String>? onOpenCharacter;

  const CharacterRelationshipGraphView({
    super.key,
    this.projectSessionId = 0,
    this.onOpenCharacter,
  });

  @override
  ConsumerState<CharacterRelationshipGraphView> createState() =>
      _CharacterRelationshipGraphViewState();
}

class _CharacterRelationshipGraphViewState
    extends ConsumerState<CharacterRelationshipGraphView> {
  static const _mapper = CharacterRelationshipGraphMapper();
  Size get _nodeSize {
    final textTheme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final bodySize = textTheme.bodyMedium?.fontSize ?? 14;
    final labelSize = textTheme.labelSmall?.fontSize ?? 11;
    final scale = math.max(
      1.0,
      math.max(scaler.scale(bodySize) / 14, scaler.scale(labelSize) / 11),
    );
    return Size.square(104 * scale);
  }

  Map<String, CharacterEntryData>? _mappedCharacters;
  CharacterRelationshipGraphData? _cachedGraph;
  CharacterRelationshipDisplayMode? _mappedMode;
  bool? _mappedMerge;
  CharacterGraphLayoutResult? _cachedLayout;
  CharacterRelationshipGraphData? _layoutGraph;
  CharacterGraphLayoutMode? _layoutMode;
  Size? _layoutNodeSize;
  int _layoutSessionRevision = -1;
  String? _hoveredEdgeId;
  bool _draggingNode = false;
  Offset _dragPointerOrigin = Offset.zero;
  Offset _dragNodeOrigin = Offset.zero;
  bool _panelExpanded = true;
  Map<String, EdgeVisualLayout>? _cachedRoutes;
  Map<String, EdgeGeometry>? _cachedGeometries;
  CharacterRelationshipGraphData? _geometryGraph;
  CharacterGraphLayoutResult? _geometryLayout;
  CharacterRelationshipGraphData? _routeGraph;
  CharacterGraphLayoutResult? _routeLayout;
  String _routeFocusKey = "";

  CharacterRelationshipGraphData _mapGraph(
    Map<String, CharacterEntryData> characters,
  ) {
    if (!identical(characters, _mappedCharacters) ||
        _mappedMode != _displayMode ||
        _mappedMerge != _controller.mergeOpposite) {
      _mappedCharacters = characters;
      _mappedMode = _displayMode;
      _mappedMerge = _controller.mergeOpposite;
      _cachedGraph = _mapper.map(
        characters,
        displayMode: _displayMode,
        mergeOpposite: _controller.mergeOpposite,
      );
    }
    return _cachedGraph!;
  }

  CharacterGraphLayoutResult _resolveLayout(
    CharacterRelationshipGraphData graph,
  ) {
    if (!identical(graph, _layoutGraph) ||
        _layoutMode != _controller.layoutMode ||
        _layoutSessionRevision != _controller.layoutSession.revision ||
        _layoutNodeSize != _nodeSize) {
      if (_layoutNodeSize != null && _layoutNodeSize != _nodeSize) {
        _controller.layoutSession.rearrange(_controller.layoutMode);
      }
      _cachedLayout = _controller.layoutSession.resolve(
        graph,
        _controller.layoutMode,
        _nodeSize,
        layoutRevision: _controller.layoutRevision,
      );
      _layoutGraph = graph;
      _layoutMode = _controller.layoutMode;
      _layoutNodeSize = _nodeSize;
      _layoutSessionRevision = _controller.layoutSession.revision;
    }
    return _cachedLayout!;
  }

  Map<String, Offset> _layoutNodes(
    CharacterRelationshipGraphData graph,
    Set<String> visibleIds,
  ) => _resolveLayout(graph).positions;
  Size _canvasSize(
    CharacterRelationshipGraphData graph,
    Set<String> visibleIds,
  ) => _resolveLayout(graph).canvasSize;

  bool _focusedEdge(
    CharacterRelationshipGraphEdge edge,
    CharacterRelationshipGraphData graph,
  ) {
    final selected = graph.edgeById(_controller.selectedEdgeId ?? "");
    if (selected != null) return selected.samePair(edge);
    final nodeId = _controller.selectedNodeId;
    return nodeId != null &&
        (edge.sourceCharacterId == nodeId || edge.targetNodeId == nodeId);
  }

  String? _hitEdge(Offset point, Map<String, EdgeVisualLayout> routes) {
    String? nearest;
    var distance =
        10 / _controller.transformationController.value.getMaxScaleOnAxis();
    for (final entry in routes.entries) {
      var previous = entry.value.geometry.start;
      for (var sample = 1; sample <= 80; sample++) {
        final g = entry.value.geometry;
        final next = quadraticPoint(g.start, g.control, g.end, sample / 80);
        final delta = next - previous;
        final length = delta.dx * delta.dx + delta.dy * delta.dy;
        final from = point - previous;
        final t = length == 0
            ? 0.0
            : ((from.dx * delta.dx + from.dy * delta.dy) / length).clamp(
                0.0,
                1.0,
              );
        final d = (point - (previous + delta * t)).distance;
        if (d < distance) {
          distance = d;
          nearest = entry.key;
        }
        previous = next;
      }
    }
    return nearest;
  }

  late final CharacterRelationshipGraphController _controller;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Size _viewportSize = Size.zero;
  bool _initialGlobalPreviewScheduled = false;
  bool _toolbarExpanded = true;
  String? _selectedSnapshotEventId;
  CharacterRelationshipDisplayMode _displayMode =
      CharacterRelationshipDisplayMode.external;

  bool get _isViewingSnapshot => _selectedSnapshotEventId != null;

  @override
  void initState() {
    super.initState();
    _controller = CharacterRelationshipGraphController()
      ..addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant CharacterRelationshipGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectSessionId == widget.projectSessionId) return;
    _searchController.clear();
    _controller.resetSession();
    _mappedCharacters = null;
    _cachedLayout = null;
    _layoutGraph = null;
    _cachedRoutes = null;
    _hoveredEdgeId = null;
    _panelExpanded = true;
    _selectedSnapshotEventId = null;
    _displayMode = CharacterRelationshipDisplayMode.external;
    _initialGlobalPreviewScheduled = false;
    _toolbarExpanded = true;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotEvents = ref.watch(characterSnapshotEventsProvider);
    final selectedSnapshotEvent = _selectedSnapshotEvent(snapshotEvents);
    final characters = selectedSnapshotEvent == null
        ? ref.watch(characterDataProvider)
        : ref.watch(
            characterDataAtSnapshotTickProvider(
              selectedSnapshotEvent.resolvedTick,
            ),
          );
    final graph = _mapGraph(characters);
    _discardMissingSelection(graph);

    if (characters.isEmpty) {
      return _buildNoCharactersState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .45,
          ),
          child: SingleChildScrollView(
            child: _buildToolbar(
              characters,
              graph,
              snapshotEvents,
              selectedSnapshotEvent,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewportSize = constraints.biggest;
              return _buildGraphCanvas(characters, graph, constraints.biggest);
            },
          ),
        ),
      ],
    );
  }

  CharacterSnapshotEvent? _selectedSnapshotEvent(
    List<CharacterSnapshotEvent> events,
  ) {
    final id = _selectedSnapshotEventId;
    if (id == null) return null;
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  void _discardMissingSelection(CharacterRelationshipGraphData graph) {
    final nodeMissing =
        _controller.selectedNodeId != null &&
        graph.nodeById(_controller.selectedNodeId!) == null;
    final edgeMissing =
        _controller.selectedEdgeId != null &&
        graph.edgeById(_controller.selectedEdgeId!) == null;
    if (!nodeMissing && !edgeMissing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.clearSelection();
    });
  }

  Widget _buildNoCharactersState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text("尚無人物資料", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text("請先到角色設定新增人物，再回來建立與查看關係。", textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(
    Map<String, CharacterEntryData> characters,
    CharacterRelationshipGraphData graph,
    List<CharacterSnapshotEvent> snapshotEvents,
    CharacterSnapshotEvent? selectedSnapshotEvent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 6,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: LargeTitle(
                    icon: Icons.people_alt_rounded,
                    text: "關係設定",
                  ),
                ),
                IconButton(
                  key: const ValueKey("relationship-toolbar-toggle"),
                  tooltip: _toolbarExpanded ? "收合工具列" : "展開工具列",
                  onPressed: () =>
                      setState(() => _toolbarExpanded = !_toolbarExpanded),
                  icon: Icon(
                    _toolbarExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ),
                if (_toolbarExpanded) ...[
                  SizedBox(
                    width: 240,
                    child: AppDropdownField<CharacterRelationshipDisplayMode>(
                      key: const ValueKey("relationship-display-selector"),
                      value: _displayMode,
                      labelText: "顯示關係",
                      options: const [
                        DropdownOption(
                          value: CharacterRelationshipDisplayMode.internal,
                          label: "內在關係",
                        ),
                        DropdownOption(
                          value: CharacterRelationshipDisplayMode.external,
                          label: "外在關係",
                        ),
                        DropdownOption(
                          value: CharacterRelationshipDisplayMode.both,
                          label: "全部",
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _displayMode = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: AppDropdownField<CharacterGraphLayoutMode>(
                      key: const ValueKey("relationship-layout-selector"),
                      value: _controller.layoutMode,
                      labelText: "角色排列",
                      options: const [
                        DropdownOption(
                          value: CharacterGraphLayoutMode.roles,
                          label: "角色定位",
                        ),
                        DropdownOption(
                          value: CharacterGraphLayoutMode.clusters,
                          label: "關係群集",
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) _controller.setLayoutMode(value);
                      },
                    ),
                  ),
                  const Text("外在 ━   內在 ┄   拖曳角色可調整位置"),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: AppDropdownField<String>(
                      key: const ValueKey("relationship-snapshot-selector"),
                      value: selectedSnapshotEvent?.id ?? "__current__",
                      labelText: "關係快照",
                      options: [
                        const DropdownOption(
                          value: "__current__",
                          label: "預設角色資料",
                        ),
                        for (final event in snapshotEvents)
                          DropdownOption(
                            value: event.id,
                            label:
                                "Tick ${event.resolvedTick} · ${event.sceneName}（${event.changedCharacterIds.length} 位角色變更）",
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSnapshotEventId = value == "__current__"
                              ? null
                              : value;
                        });
                      },
                    ),
                  ),
                  if (selectedSnapshotEvent != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: AppNoticeBanner(
                        message:
                            "正在檢視 Tick ${selectedSnapshotEvent.resolvedTick} 的關係快照；每位角色皆採用自己在此 Tick 前最後一次變更的關係。",
                        icon: Icons.history_toggle_off_outlined,
                        tone: AppFeedbackTone.info,
                      ),
                    ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: RawAutocomplete<String>(
                      textEditingController: _searchController,
                      focusNode: _searchFocusNode,
                      optionsBuilder: (textEditingValue) => _buildSearchOptions(
                        characters,
                        textEditingValue.text,
                      ),
                      onSelected: (_) =>
                          _focusFirstSearchResult(characters, graph),
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) => TextField(
                            key: const ValueKey("relationship-search-field"),
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: appFieldDecoration(
                              context,
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(
                                  Icons.person_search_outlined,
                                ),
                                hintText: "搜尋或選擇人物",
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_searchController.text.isNotEmpty)
                                      IconButton(
                                        tooltip: "清除搜尋",
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.clear),
                                      ),
                                    IconButton(
                                      key: const ValueKey(
                                        "relationship-search-button",
                                      ),
                                      tooltip: "搜尋並聚焦",
                                      onPressed: () => _focusFirstSearchResult(
                                        characters,
                                        graph,
                                      ),
                                      icon: const Icon(
                                        Icons.center_focus_strong,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) {
                              onFieldSubmitted();
                              _focusFirstSearchResult(characters, graph);
                            },
                          ),
                      optionsViewBuilder: (context, onSelected, options) =>
                          Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              borderRadius: AppSurfaceShape.borderRadius,
                              clipBehavior: Clip.antiAlias,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 240,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        key: ValueKey(
                                          "relationship-search-option-$option",
                                        ),
                                        dense: true,
                                        leading: const Icon(
                                          Icons.person_outline,
                                        ),
                                        title: Text(option),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey("neighbors-only-toggle-button"),
                    tooltip: "只顯示一階鄰居",
                    isSelected: _controller.neighborsOnly,
                    style: _controller.neighborsOnly
                        ? IconButton.styleFrom(foregroundColor: Colors.green)
                        : null,
                    onPressed: _controller.selectedNodeId == null
                        ? null
                        : () => _controller.setNeighborsOnly(
                            !_controller.neighborsOnly,
                          ),
                    icon: const Icon(Icons.hub_outlined),
                  ),
                  IconButton(
                    key: const ValueKey("global-preview-button"),
                    tooltip: "全局預覽",
                    onPressed: () => _showGlobalPreview(graph, _viewportSize),
                    icon: const Icon(Icons.fit_screen_outlined),
                  ),
                  IconButton(
                    tooltip: "新增關係",
                    onPressed: _isViewingSnapshot
                        ? null
                        : () => _addRelationship(characters),
                    icon: const Icon(Icons.add_link),
                  ),
                  IconButton(
                    tooltip: "自動重新排列",
                    onPressed: () => _rearrangeGraph(graph),
                    icon: const Icon(Icons.auto_fix_high_outlined),
                  ),
                  IconButton(
                    tooltip: "重設縮放",
                    onPressed: _controller.resetZoom,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: "縮小",
                    onPressed: () => _controller.zoomBy(0.8, _viewportSize),
                    icon: const Icon(Icons.zoom_out),
                  ),
                  IconButton(
                    tooltip: "放大",
                    onPressed: () => _controller.zoomBy(1.25, _viewportSize),
                    icon: const Icon(Icons.zoom_in),
                  ),
                  IconButton(
                    key: const ValueKey("relationship-merge-toggle"),
                    tooltip: "合併相同的雙向關係",
                    isSelected: _controller.mergeOpposite,
                    style: _controller.mergeOpposite
                        ? IconButton.styleFrom(foregroundColor: Colors.green)
                        : null,
                    onPressed: () => _controller.setMergeOpposite(
                      !_controller.mergeOpposite,
                    ),
                    icon: const Icon(Icons.merge_rounded),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _rearrangeGraph(CharacterRelationshipGraphData graph) {
    _controller.rearrange();
    final selected =
        _controller.selectedNodeId ??
        graph.edgeById(_controller.selectedEdgeId ?? "")?.sourceCharacterId;
    if (selected == null || _viewportSize.isEmpty) return;
    final position = _resolveLayout(graph).positions[selected];
    if (position == null) return;
    final matrix = _controller.transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final center = position + Offset(_nodeSize.width / 2, _nodeSize.height / 2);
    final screen =
        center * scale + Offset(matrix.storage[12], matrix.storage[13]);
    if ((Offset.zero & _viewportSize).deflate(40).contains(screen)) return;
    final shift =
        Offset(_viewportSize.width / 2, _viewportSize.height / 2) - screen;
    _controller.transformationController.value = matrix.clone()
      ..setTranslationRaw(
        matrix.storage[12] + shift.dx,
        matrix.storage[13] + shift.dy,
        0,
      );
  }

  void _showGlobalPreview(
    CharacterRelationshipGraphData graph,
    Size viewportSize,
  ) {
    _controller.resetToGlobalPreview();
    _controller.fitCanvas(
      viewportSize,
      _canvasSize(graph, graph.nodes.map((node) => node.id).toSet()),
    );
  }

  void _scheduleInitialGlobalPreview(
    CharacterRelationshipGraphData graph,
    Size viewportSize,
  ) {
    if (_initialGlobalPreviewScheduled || viewportSize.isEmpty) return;
    _initialGlobalPreviewScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showGlobalPreview(graph, viewportSize);
    });
  }

  Iterable<String> _buildSearchOptions(
    Map<String, CharacterEntryData> characters,
    String input,
  ) {
    final query = input.trim().toLowerCase();
    return characters.entries
        .where(
          (entry) =>
              query.isEmpty ||
              _matchesCharacterSearch(entry, query, characters),
        )
        .map(
          (entry) =>
              CharacterRelationshipResolver.displayLabel(entry.key, characters),
        );
  }

  bool _matchesCharacterSearch(
    MapEntry<String, CharacterEntryData> entry,
    String query,
    Map<String, CharacterEntryData> characters,
  ) {
    final character = entry.value;
    final displayName = character.displayName.isEmpty
        ? character.textFields["name"] ?? entry.key
        : character.displayName;
    final label = CharacterRelationshipResolver.displayLabel(
      entry.key,
      characters,
    );
    final aliases = character.aliases.expand((alias) => alias.values);
    return displayName.toLowerCase().contains(query) ||
        label.toLowerCase().contains(query) ||
        character.nanoId.toLowerCase().contains(query) ||
        aliases.any((alias) => alias.toLowerCase().contains(query));
  }

  void _focusFirstSearchResult(
    Map<String, CharacterEntryData> characters,
    CharacterRelationshipGraphData graph,
  ) {
    final rawQuery = _searchController.text.trim();
    if (rawQuery.isEmpty) return;
    final exact = CharacterRelationshipResolver(characters).resolve(rawQuery);
    String? matchId = exact.isResolved ? exact.characterId : null;
    final query = rawQuery.toLowerCase();
    if (matchId == null) {
      for (final entry in characters.entries) {
        if (_matchesCharacterSearch(entry, query, characters)) {
          matchId = entry.key;
          break;
        }
      }
    }
    if (matchId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("找不到符合的人物")));
      return;
    }
    _controller.selectNode(matchId);
    final visible = _controller.visibleNodeIds(graph);
    final positions = _layoutNodes(graph, visible);
    final position = positions[matchId];
    if (position == null || _viewportSize.isEmpty) return;
    const scale = 1.15;
    final center = position + Offset(_nodeSize.width / 2, _nodeSize.height / 2);
    final dx = _viewportSize.width / 2 - center.dx * scale;
    final dy = _viewportSize.height / 2 - center.dy * scale;
    _controller.transformationController.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, scale)
      ..setTranslationRaw(dx, dy, 0);
  }

  Widget _buildGraphCanvas(
    Map<String, CharacterEntryData> characters,
    CharacterRelationshipGraphData graph,
    Size viewportSize,
  ) {
    _scheduleInitialGlobalPreview(graph, viewportSize);
    final visibleIds = _controller.visibleNodeIds(graph);
    final positions = _layoutNodes(graph, visibleIds);
    final canvasSize = _canvasSize(graph, visibleIds);
    final visibleEdges = _edgesByConnectionDensity(
      graph.edges.where(
        (edge) =>
            visibleIds.contains(edge.sourceCharacterId) &&
            visibleIds.contains(edge.targetNodeId),
      ),
    );
    final layout = _resolveLayout(graph);
    if (!identical(_geometryGraph, graph) ||
        !identical(_geometryLayout, layout)) {
      _cachedGeometries = routeCharacterEdgeGeometries(
        graph.edges,
        positions,
        canvasSize,
        nodeSize: _nodeSize,
      );
      _geometryGraph = graph;
      _geometryLayout = layout;
    }
    final labelFontSize =
        Theme.of(context).textTheme.labelSmall?.fontSize ?? 11;
    final scaledLabelSize = MediaQuery.textScalerOf(
      context,
    ).scale(labelFontSize);
    final focusKey =
        "${_controller.selectedNodeId}:${_controller.selectedEdgeId}:$_hoveredEdgeId:$scaledLabelSize:${visibleIds.toList()..sort()}";
    if (!identical(_routeGraph, graph) ||
        !identical(_routeLayout, layout) ||
        _routeFocusKey != focusKey) {
      final labeled = visibleEdges
          .where((e) => _focusedEdge(e, graph) || e.id == _hoveredEdgeId)
          .map((e) => e.id)
          .toSet();
      final priorityEdges = [...visibleEdges]
        ..sort((a, b) {
          final aPriority = a.id == _controller.selectedEdgeId
              ? 2
              : labeled.contains(a.id)
              ? 1
              : 0;
          final bPriority = b.id == _controller.selectedEdgeId
              ? 2
              : labeled.contains(b.id)
              ? 1
              : 0;
          return bPriority.compareTo(aPriority);
        });
      _cachedRoutes = placeCharacterEdgeLabels(
        priorityEdges,
        _cachedGeometries!,
        positions,
        canvasSize,
        nodeSize: _nodeSize,
        labelSizes: {for (final e in priorityEdges) e.id: _edgeLabelSizeFor(e)},
        labeledEdgeIds: labeled,
      );
      _routeGraph = graph;
      _routeLayout = layout;
      _routeFocusKey = focusKey;
    }
    final edgeVisualLayouts = _cachedRoutes!;
    final selectedEdge = graph.edgeById(_controller.selectedEdgeId ?? "");
    final connectedIds = selectedEdge != null
        ? {selectedEdge.sourceCharacterId, selectedEdge.targetNodeId}
        : _connectedNodeIds(graph, _controller.selectedNodeId);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (event) {
              final point = _controller.transformationController.toScene(
                event.localPosition,
              );
              final id = _hitEdge(point, edgeVisualLayouts);
              if (id == null) {
                _controller.clearSelection();
              } else {
                _controller.selectEdge(id);
              }
            },
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: InteractiveViewer(
                transformationController: _controller.transformationController,
                constrained: false,
                panEnabled: !_draggingNode,
                minScale: 0.05,
                maxScale: 3,
                boundaryMargin: const EdgeInsets.all(600),
                child: SizedBox(
                  key: const ValueKey("relationship-graph-canvas"),
                  width: canvasSize.width,
                  height: canvasSize.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: MouseRegion(
                          onHover: (event) {
                            final id = _hitEdge(
                              event.localPosition,
                              edgeVisualLayouts,
                            );
                            if (id != _hoveredEdgeId) {
                              setState(() => _hoveredEdgeId = id);
                            }
                          },
                          onExit: (_) {
                            if (_hoveredEdgeId != null) {
                              setState(() => _hoveredEdgeId = null);
                            }
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (event) {
                              final id = _hitEdge(
                                event.localPosition,
                                edgeVisualLayouts,
                              );
                              if (id == null) {
                                _controller.clearSelection();
                              } else {
                                _controller.selectEdge(id);
                                _panelExpanded = true;
                              }
                            },
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: const ValueKey("relationship-edge-layer"),
                            painter: _RelationshipEdgesPainter(
                              edges: visibleEdges,
                              geometries: {
                                for (final entry in edgeVisualLayouts.entries)
                                  entry.key: entry.value.geometry,
                              },
                              selectedEdgeId: _controller.selectedEdgeId,
                              selectedNodeId: _controller.selectedNodeId,
                              focusedEdgeIds: visibleEdges
                                  .where(
                                    (e) =>
                                        _focusedEdge(e, graph) ||
                                        e.id == _hoveredEdgeId,
                                  )
                                  .map((e) => e.id)
                                  .toSet(),
                              colorScheme: Theme.of(context).colorScheme,
                            ),
                          ),
                        ),
                      ),
                      for (final edge in visibleEdges)
                        if ((_focusedEdge(edge, graph) ||
                                edge.id == _hoveredEdgeId) &&
                            edgeVisualLayouts[edge.id]!.label.visible)
                          _buildEdgeLabel(
                            edge,
                            edgeVisualLayouts[edge.id]!.label,
                          ),
                      for (final node in graph.nodes)
                        if (visibleIds.contains(node.id))
                          _buildNode(node, positions[node.id]!, connectedIds),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (graph.edges.isEmpty)
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.link_off_outlined),
                    const SizedBox(width: 10),
                    const Expanded(child: Text("目前沒有關係；可在此新增，或回到角色設定編輯。")),
                    TextButton.icon(
                      onPressed: _isViewingSnapshot
                          ? null
                          : () => _addRelationship(characters),
                      icon: const Icon(Icons.add),
                      label: const Text("新增"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        _buildSelectionPanel(characters, graph),
      ],
    );
  }

  Widget _buildNode(
    CharacterRelationshipGraphNode node,
    Offset position,
    Set<String> connectedIds,
  ) {
    final selected = node.id == _controller.selectedNodeId;
    final hasSelection =
        _controller.selectedNodeId != null ||
        _controller.selectedEdgeId != null;
    final emphasized = selected || connectedIds.contains(node.id);
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      key: ValueKey("relationship-node-${node.id}"),
      left: position.dx,
      top: position.dy,
      width: _nodeSize.width,
      height: _nodeSize.height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: !hasSelection || emphasized ? 1 : 0.35,
        child: Material(
          color: node.isUnresolved
              ? scheme.errorContainer
              : selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          elevation: selected ? 8 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: AppSurfaceShape.borderRadius,
            side: BorderSide(
              color: node.isUnresolved
                  ? scheme.error
                  : selected
                  ? scheme.primary
                  : scheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onTap: () {
              _panelExpanded = true;
              _controller.selectNode(node.id);
            },
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: (details) {
              _dragPointerOrigin = details.globalPosition;
              _dragNodeOrigin = _cachedLayout!.positions[node.id]!;
              _controller.selectNode(node.id);
              setState(() => _draggingNode = true);
            },
            onPanUpdate: (details) {
              final scale = _controller.transformationController.value
                  .getMaxScaleOnAxis();
              _controller.moveNode(
                node.id,
                _dragNodeOrigin +
                    (details.globalPosition - _dragPointerOrigin) / scale,
              );
            },
            onPanEnd: (_) => setState(() => _draggingNode = false),
            onPanCancel: () => setState(() => _draggingNode = false),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    node.isUnresolved
                        ? Icons.person_off_outlined
                        : Icons.person_outline,
                    size: 30,
                    color: node.isUnresolved ? scheme.error : scheme.primary,
                  ),
                  if (_controller.layoutSession.pinned.contains(node.id))
                    const Icon(Icons.push_pin, size: 12),
                  if (node.character?.characterType.trim().isNotEmpty ?? false)
                    Text(
                      node.character!.characterType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      node.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        height: 1.12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeLabel(
    CharacterRelationshipGraphEdge edge,
    EdgeLabelPlacement placement,
  ) {
    final label = "${edge.layerLabel}：${edge.description}";
    final selected = edge.id == _controller.selectedEdgeId;
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      key: ValueKey("relationship-edge-label-${edge.id}"),
      left: placement.center.dx - placement.size.width / 2,
      top: placement.center.dy - placement.size.height / 2,
      width: placement.size.width,
      height: placement.size.height,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? scheme.secondaryContainer : scheme.surface,
          elevation: selected ? 4 : 1,
          borderRadius: AppSurfaceShape.borderRadius,
          child: InkWell(
            borderRadius: AppSurfaceShape.borderRadius,
            onTap: () => _controller.selectEdge(edge.id),
            child: Padding(
              padding: AppSpacing.badgePadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!edge.isResolved) ...[
                    Icon(Icons.warning_amber, size: 14, color: scheme.error),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionPanel(
    Map<String, CharacterEntryData> characters,
    CharacterRelationshipGraphData graph,
  ) {
    final edge = _controller.selectedEdgeId == null
        ? null
        : graph.edgeById(_controller.selectedEdgeId!);
    final node = _controller.selectedNodeId == null
        ? null
        : graph.nodeById(_controller.selectedNodeId!);
    if (edge == null && node == null) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Align(
        alignment: Alignment.bottomRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: math.max(60, _viewportSize.height * .6),
          ),
          child: Card(
            elevation: 10,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      key: const ValueKey("relationship-panel-toggle"),
                      onPressed: () =>
                          setState(() => _panelExpanded = !_panelExpanded),
                      icon: Icon(
                        _panelExpanded ? Icons.expand_more : Icons.expand_less,
                      ),
                      label: Text(_panelExpanded ? "收合詳細資料" : "展開詳細資料"),
                    ),
                    if (_panelExpanded)
                      edge != null
                          ? _buildEdgeDetails(characters, graph, edge)
                          : _buildNodeDetails(characters, graph, node!),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNodeDetails(
    Map<String, CharacterEntryData> characters,
    CharacterRelationshipGraphData graph,
    CharacterRelationshipGraphNode node,
  ) {
    if (node.isUnresolved) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(node.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text("此名稱目前無法唯一對應到人物資料。請選取連線進行修正。"),
        ],
      );
    }
    final character = node.character!;
    final organizations = character.organizations
        .where((organization) => organization.name.trim().isNotEmpty)
        .toList(growable: false);
    final adjacent = graph.edges
        .where(
          (edge) =>
              edge.sourceCharacterId == node.id || edge.targetNodeId == node.id,
        )
        .length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                node.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: "開啟人物編輯",
              onPressed: widget.onOpenCharacter == null
                  ? null
                  : () => widget.onOpenCharacter!(node.id),
              icon: const Icon(Icons.edit_rounded),
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
              ),
            ),
            IconButton(
              tooltip: "關閉",
              onPressed: _controller.clearSelection,
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
        ),
        if (character.roleOrOccupation.trim().isNotEmpty)
          Text("職業：${character.roleOrOccupation}"),
        if (character.age.trim().isNotEmpty) Text("年齡：${character.age}"),
        if (character.gender.trim().isNotEmpty) Text("性別：${character.gender}"),
        if (character.personalitySummary.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            character.personalitySummary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (organizations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.apartment_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                "所屬組織",
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final entry in organizations.asMap().entries)
                Tooltip(
                  message: entry.value.description.trim(),
                  child: Chip(
                    key: ValueKey(
                      "relationship-node-organization-chip-${node.id}-${entry.key}",
                    ),
                    avatar: Icon(
                      Icons.apartment_outlined,
                      size: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 230),
                      child: Text(
                        entry.value.name.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLow,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text("相鄰關係：$adjacent"),
        OutlinedButton.icon(
          key: ValueKey("relationship-pin-${node.id}"),
          onPressed: () => _controller.togglePin(node.id),
          icon: const Icon(Icons.push_pin_outlined),
          label: Text(
            _controller.layoutSession.pinned.contains(node.id)
                ? "解除釘選"
                : "釘選位置",
          ),
        ),
        if (_pinnedOverlap(node.id))
          Text(
            "釘選位置與其他釘選角色重疊，可拖曳調整。",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final related in graph.edges.where(
          (e) => e.sourceCharacterId == node.id || e.targetNodeId == node.id,
        ))
          ListTile(
            dense: true,
            key: ValueKey("relationship-neighbor-${related.id}"),
            title: Text(
              "${graph.nodeById(related.sourceCharacterId)?.label} ${related.isBidirectional ? '↔' : '→'} ${graph.nodeById(related.targetNodeId)?.label}",
            ),
            subtitle: Text("${related.layerLabel}：${related.description}"),
            onTap: () => _controller.selectEdge(related.id),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _isViewingSnapshot
                  ? null
                  : () => _addRelationship(
                      characters,
                      sourceCharacterId: node.id,
                    ),
              icon: const Icon(Icons.add_link),
              label: const Text("新增關係"),
            ),
            OutlinedButton.icon(
              onPressed: _isViewingSnapshot
                  ? null
                  : () => _createTargetFromNode(node.id),
              icon: const Icon(Icons.person_add_alt),
              label: const Text("建立目標人物"),
            ),
          ],
        ),
      ],
    );
  }

  bool _pinnedOverlap(String id) {
    final pins = _controller.layoutSession.pinned;
    final positions = _cachedLayout?.positions;
    if (!pins.contains(id) || positions == null || !positions.containsKey(id)) {
      return false;
    }
    final rect = positions[id]! & _nodeSize;
    return pins.any(
      (other) =>
          other != id &&
          positions.containsKey(other) &&
          rect.overlaps(positions[other]! & _nodeSize),
    );
  }

  Widget _buildEdgeDetails(
    Map<String, CharacterEntryData> characters,
    CharacterRelationshipGraphData graph,
    CharacterRelationshipGraphEdge edge,
  ) {
    final channels = graph.edges.where(edge.samePair).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "${graph.nodeById(edge.canonicalSource)?.label} 與 ${graph.nodeById(edge.canonicalTarget)?.label}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: "關閉",
              onPressed: _controller.clearSelection,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        Text(
          "目前顯示：${_displayMode == CharacterRelationshipDisplayMode.both
              ? '全部'
              : _displayMode == CharacterRelationshipDisplayMode.external
              ? '外在'
              : '內在'}",
        ),
        if (_displayMode != CharacterRelationshipDisplayMode.both)
          TextButton(
            onPressed: () => setState(
              () => _displayMode = CharacterRelationshipDisplayMode.both,
            ),
            child: const Text("顯示全部關係"),
          ),
        for (final channel in channels) ...[
          _buildDirectionDetails(characters, graph, channel, channel.sources),
          if (channel.isBidirectional)
            _buildDirectionDetails(
              characters,
              graph,
              channel,
              channel.reverseSources,
            ),
        ],
        if (!edge.isResolved) ...[
          Text(
            edge.resolutionKind == CharacterRelationshipResolutionKind.ambiguous
                ? "有多位同名人物，請編輯並選擇含 NanoID 的人物。"
                : "找不到對應人物，可修正名稱或建立新人物。",
          ),
          if (edge.resolutionKind ==
              CharacterRelationshipResolutionKind.unresolved)
            OutlinedButton.icon(
              onPressed: _isViewingSnapshot
                  ? null
                  : () => _createCharacterForEdge(edge),
              icon: const Icon(Icons.person_add_alt),
              label: const Text("建立人物"),
            ),
        ],
      ],
    );
  }

  Widget _buildDirectionDetails(
    Map<String, CharacterEntryData> characters,
    CharacterRelationshipGraphData graph,
    CharacterRelationshipGraphEdge edge,
    List<CharacterRelationshipSource> sources,
  ) {
    final sourceId = sources.first.characterId;
    final targetId = sourceId == edge.sourceCharacterId
        ? edge.targetNodeId
        : edge.sourceCharacterId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "${graph.nodeById(sourceId)?.label} → ${graph.nodeById(targetId)?.label} · ${edge.layerLabel}",
            ),
            Text(edge.description),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: ValueKey(
                    "relationship-edit-$sourceId-${edge.layer.name}",
                  ),
                  onPressed: _isViewingSnapshot
                      ? null
                      : () => _editChannel(characters, edge, sources),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text("編輯"),
                ),
                TextButton(
                  onPressed: _isViewingSnapshot
                      ? null
                      : () => _repairTarget(sources),
                  child: const Text("修正目標人物"),
                ),
                TextButton.icon(
                  key: ValueKey(
                    "relationship-delete-$sourceId-${edge.layer.name}",
                  ),
                  onPressed: _isViewingSnapshot
                      ? null
                      : () => _deleteChannel(edge, sources),
                  icon: const Icon(Icons.delete_outline),
                  label: Text("刪除${edge.layerLabel}"),
                ),
                TextButton(
                  onPressed: _isViewingSnapshot
                      ? null
                      : () => _deleteChannel(
                          edge,
                          sources,
                          entireDirection: true,
                        ),
                  child: const Text("刪除此方向全部關係"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyChannelChange(
    List<CharacterRelationshipSource> sources,
    CharacterRelationshipLayer layer,
    String description, {
    bool entireDirection = false,
  }) {
    final current = ref.read(characterDataProvider);
    final next = updateCharacterRelationshipChannel(
      current,
      sources: sources,
      layer: layer,
      description: description,
      deleteDirection: entireDirection,
    );
    if (next == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("關係已變更，請重新選取後再操作。")));
      _controller.clearSelection();
      return;
    }
    ref.read(characterDataProvider.notifier).setCharacterData(next);
    _controller.clearSelection();
  }

  Future<void> _editChannel(
    Map<String, CharacterEntryData> characters,
    CharacterRelationshipGraphEdge edge,
    List<CharacterRelationshipSource> sources,
  ) async {
    final session = widget.projectSessionId;
    final sourceId = sources.first.characterId;
    final result = await AppDialog.prompt(
      context: context,
      title:
          "${characters[sourceId]?.displayName} → ${sources.first.value.person} · 編輯${edge.layerLabel}關係",
      labelText: "${edge.layerLabel}關係",
      initialValue: edge.description,
      confirmLabel: "儲存",
      allowEmpty: true,
    );
    if (result == null ||
        !mounted ||
        _isViewingSnapshot ||
        session != widget.projectSessionId) {
      return;
    }
    _applyChannelChange(sources, edge.layer, result.trim());
  }

  Future<void> _deleteChannel(
    CharacterRelationshipGraphEdge edge,
    List<CharacterRelationshipSource> sources, {
    bool entireDirection = false,
  }) async {
    final session = widget.projectSessionId;
    final confirmed = await AppDialog.confirm(
      context: context,
      title: "刪除人物關係",
      message: entireDirection
          ? "確定刪除此方向的外在與內在關係？反向關係會保留。"
          : "確定刪除此方向的${edge.layerLabel}關係「${edge.description}」？另一類型與反向關係會保留。",
      confirmLabel: "刪除",
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!confirmed ||
        !mounted ||
        _isViewingSnapshot ||
        session != widget.projectSessionId) {
      return;
    }
    _applyChannelChange(
      sources,
      edge.layer,
      "",
      entireDirection: entireDirection,
    );
  }

  Future<void> _repairTarget(List<CharacterRelationshipSource> sources) async {
    final session = widget.projectSessionId;
    final characters = ref.read(characterDataProvider);
    final person = await AppDialog.showCustom<String>(
      context: context,
      builder: (_) => _RelationshipTargetDialog(
        initialPerson: sources.first.value.person,
        options: [
          for (final id in characters.keys)
            CharacterRelationshipResolver.displayLabel(id, characters),
        ],
      ),
    );
    if (!mounted ||
        person == null ||
        person.isEmpty ||
        _isViewingSnapshot ||
        session != widget.projectSessionId) {
      return;
    }
    final current = ref.read(characterDataProvider);
    final resolution = CharacterRelationshipResolver(current).resolve(person);
    if (!resolution.isResolved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請從清單選擇能唯一對應的現有人物。")));
      return;
    }
    final next = updateCharacterRelationshipChannel(
      current,
      sources: sources,
      layer: CharacterRelationshipLayer.external,
      description: "",
      targetPerson: CharacterRelationshipResolver.displayLabel(
        resolution.characterId!,
        current,
      ),
    );
    if (next == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("關係已變更，請重新選取後再操作。")));
    } else {
      ref.read(characterDataProvider.notifier).setCharacterData(next);
    }
    _controller.clearSelection();
  }

  Future<void> _addRelationship(
    Map<String, CharacterEntryData> characters, {
    String? sourceCharacterId,
  }) async {
    final session = widget.projectSessionId;
    final selectedSource =
        sourceCharacterId ??
        (characters.containsKey(_controller.selectedNodeId)
            ? _controller.selectedNodeId
            : null);
    final result = await CharacterRelationshipEditor.show(
      context: context,
      characters: characters,
      sourceCharacterId: selectedSource,
      allowSourceSelection: selectedSource == null,
    );
    if (result == null ||
        !mounted ||
        _isViewingSnapshot ||
        session != widget.projectSessionId) {
      return;
    }
    _writeRelationship(result);
  }

  void _writeRelationship(CharacterRelationshipEditorResult result) {
    final next = Map<String, CharacterEntryData>.of(
      ref.read(characterDataProvider),
    );
    final source = next[result.sourceCharacterId];
    if (source == null) return;

    final resolution = CharacterRelationshipResolver(
      next,
    ).resolve(result.person);
    if (resolution.kind == CharacterRelationshipResolutionKind.ambiguous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("有多位同名人物，請從清單選擇含 NanoID 的人物")),
      );
      return;
    }

    late final String targetCharacterId;
    if (resolution.isResolved) {
      targetCharacterId = resolution.characterId!;
    } else {
      final target = CharacterEntryData.withName(result.person.trim());
      targetCharacterId = target.characterId;
      next[targetCharacterId] = target;
    }

    final targetLabel = CharacterRelationshipResolver.displayLabel(
      targetCharacterId,
      next,
    );
    next[result.sourceCharacterId] = source.copyWith(
      relationships: upsertCharacterRelationship(
        relationships: source.relationships,
        person: targetLabel,
        description: result.description,
        internalRelationship: result.internalRelationship,
      ),
    );

    if (result.bidirectional && targetCharacterId != result.sourceCharacterId) {
      final target = next[targetCharacterId]!;
      final sourceLabel = CharacterRelationshipResolver.displayLabel(
        result.sourceCharacterId,
        next,
      );
      next[targetCharacterId] = target.copyWith(
        relationships: upsertCharacterRelationship(
          relationships: target.relationships,
          person: sourceLabel,
          description: result.description,
          internalRelationship: result.internalRelationship,
        ),
      );
    }

    ref.read(characterDataProvider.notifier).setCharacterData(next);
  }

  Future<void> _createCharacterForEdge(
    CharacterRelationshipGraphEdge edge,
  ) async {
    final session = widget.projectSessionId;
    final rawName = edge.rawTargetPerson.trim();
    final name = await AppDialog.prompt(
      context: context,
      title: "建立目標人物",
      message: "建立後，這筆關係會依人物名稱自動連結。",
      labelText: "人物名稱",
      initialValue: rawName,
      confirmLabel: "建立",
      icon: Icons.person_add_alt,
    );
    if (name == null ||
        !mounted ||
        _isViewingSnapshot ||
        session != widget.projectSessionId) {
      return;
    }
    final entry = CharacterEntryData.withName(name);
    final current = Map<String, CharacterEntryData>.of(
      ref.read(characterDataProvider),
    )..[entry.characterId] = entry;
    final next = updateCharacterRelationshipChannel(
      current,
      sources: edge.sources,
      layer: edge.layer,
      description: "",
      targetPerson: CharacterRelationshipResolver.displayLabel(
        entry.characterId,
        current,
      ),
    );
    if (next == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("關係已變更，請重新選取後再操作。")));
      return;
    }
    ref.read(characterDataProvider.notifier).setCharacterData(next);
    _controller.selectNode(entry.characterId);
  }

  Future<void> _createTargetFromNode(String sourceCharacterId) async {
    final session = widget.projectSessionId;
    final name = await AppDialog.prompt(
      context: context,
      title: "建立目標人物",
      message: "新人物建立後，會同時新增由目前人物指向他的關係。",
      labelText: "人物名稱",
      confirmLabel: "下一步",
      icon: Icons.person_add_alt,
    );
    if (name == null ||
        !mounted ||
        _isViewingSnapshot ||
        session != widget.projectSessionId) {
      return;
    }
    final target = CharacterEntryData.withName(name);
    ref
        .read(characterDataProvider.notifier)
        .setCharacterEntry(characterId: target.characterId, entry: target);
    final result = await CharacterRelationshipEditor.show(
      context: context,
      characters: ref.read(characterDataProvider),
      sourceCharacterId: sourceCharacterId,
      initialPerson: CharacterRelationshipResolver.displayLabel(
        target.characterId,
        ref.read(characterDataProvider),
      ),
      allowSourceSelection: false,
      title: "設定新人物關係",
    );
    if (result != null &&
        mounted &&
        !_isViewingSnapshot &&
        session == widget.projectSessionId) {
      _writeRelationship(result);
    }
  }

  Set<String> _connectedNodeIds(
    CharacterRelationshipGraphData graph,
    String? selectedId,
  ) {
    if (selectedId == null) return const {};
    final result = <String>{selectedId};
    for (final edge in graph.edges) {
      if (edge.sourceCharacterId == selectedId) result.add(edge.targetNodeId);
      if (edge.targetNodeId == selectedId) result.add(edge.sourceCharacterId);
    }
    return result;
  }

  Size _edgeLabelSizeFor(CharacterRelationshipGraphEdge edge) {
    final label = "${edge.layerLabel}：${edge.description}";
    final style = Theme.of(context).textTheme.labelSmall;
    final scaler = MediaQuery.textScalerOf(context);
    final baseFontSize = style?.fontSize ?? 11;
    final textScale = math.max(1.0, scaler.scale(baseFontSize) / 11);
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 2,
      ellipsis: "…",
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout(maxWidth: 190 * textScale);
    final warningWidth = edge.isResolved ? 0.0 : 18.0;
    final size = Size(
      math.max(56.0, painter.width + 16 + warningWidth),
      math.max(30.0, painter.height + 10),
    );
    painter.dispose();
    return size;
  }

  List<CharacterRelationshipGraphEdge> _edgesByConnectionDensity(
    Iterable<CharacterRelationshipGraphEdge> source,
  ) {
    final edges = source.toList(growable: false);
    final degrees = <String, int>{};
    for (final edge in edges) {
      degrees[edge.sourceCharacterId] =
          (degrees[edge.sourceCharacterId] ?? 0) + 1;
      degrees[edge.targetNodeId] = (degrees[edge.targetNodeId] ?? 0) + 1;
    }
    return [...edges]..sort((left, right) {
      final leftMaximum = math.max(
        degrees[left.sourceCharacterId] ?? 0,
        degrees[left.targetNodeId] ?? 0,
      );
      final rightMaximum = math.max(
        degrees[right.sourceCharacterId] ?? 0,
        degrees[right.targetNodeId] ?? 0,
      );
      final maximumOrder = rightMaximum.compareTo(leftMaximum);
      if (maximumOrder != 0) return maximumOrder;
      final leftTotal =
          (degrees[left.sourceCharacterId] ?? 0) +
          (degrees[left.targetNodeId] ?? 0);
      final rightTotal =
          (degrees[right.sourceCharacterId] ?? 0) +
          (degrees[right.targetNodeId] ?? 0);
      final totalOrder = rightTotal.compareTo(leftTotal);
      if (totalOrder != 0) return totalOrder;
      return left.id.compareTo(right.id);
    });
  }
}

class _RelationshipEdgesPainter extends CustomPainter {
  final List<CharacterRelationshipGraphEdge> edges;
  final Map<String, EdgeGeometry> geometries;
  final String? selectedEdgeId;
  final String? selectedNodeId;
  final ColorScheme colorScheme;
  final Set<String> focusedEdgeIds;

  const _RelationshipEdgesPainter({
    required this.edges,
    required this.geometries,
    required this.selectedEdgeId,
    required this.selectedNodeId,
    required this.colorScheme,
    required this.focusedEdgeIds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final geometry = geometries[edge.id];
      if (geometry == null) continue;
      final selected = edge.id == selectedEdgeId;
      final connected = focusedEdgeIds.contains(edge.id);
      final color = !edge.isResolved
          ? colorScheme.error
          : selected
          ? colorScheme.secondary
          : edge.layer == CharacterRelationshipLayer.internal
          ? colorScheme.tertiary
          : colorScheme.outline;
      final paint = Paint()
        ..color = color.withValues(alpha: connected ? 1 : 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3.5 : 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(geometry.start.dx, geometry.start.dy)
        ..quadraticBezierTo(
          geometry.control.dx,
          geometry.control.dy,
          geometry.end.dx,
          geometry.end.dy,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = colorScheme.surface.withValues(
            alpha: connected ? 0.82 : 0.25,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 8 : 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (edge.layer == CharacterRelationshipLayer.internal) {
        for (final metric in path.computeMetrics()) {
          for (var offset = 0.0; offset < metric.length; offset += 14) {
            canvas.drawPath(
              metric.extractPath(offset, math.min(offset + 8, metric.length)),
              paint,
            );
          }
        }
      } else {
        canvas.drawPath(path, paint);
      }

      _drawArrowHead(
        canvas,
        paint,
        point: geometry.end,
        tangent: geometry.end - geometry.control,
      );
      if (edge.isBidirectional) {
        _drawArrowHead(
          canvas,
          paint,
          point: geometry.start,
          tangent: geometry.start - geometry.control,
        );
      }
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    Paint paint, {
    required Offset point,
    required Offset tangent,
  }) {
    final angle = math.atan2(tangent.dy, tangent.dx);
    const arrowLength = 12.0;
    const arrowAngle = math.pi / 7;
    final arrow = Path()
      ..moveTo(point.dx, point.dy)
      ..lineTo(
        point.dx - arrowLength * math.cos(angle - arrowAngle),
        point.dy - arrowLength * math.sin(angle - arrowAngle),
      )
      ..moveTo(point.dx, point.dy)
      ..lineTo(
        point.dx - arrowLength * math.cos(angle + arrowAngle),
        point.dy - arrowLength * math.sin(angle + arrowAngle),
      );
    canvas.drawPath(arrow, paint);
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared < 0.0001) return (point - start).distance;
    final projection =
        ((point - start).dx * segment.dx + (point - start).dy * segment.dy) /
        lengthSquared;
    final t = projection.clamp(0.0, 1.0);
    return (point - (start + segment * t)).distance;
  }

  @override
  bool hitTest(Offset position) {
    for (final geometry in geometries.values) {
      var previous = geometry.start;
      for (var sample = 1; sample <= 120; sample++) {
        final point = quadraticPoint(
          geometry.start,
          geometry.control,
          geometry.end,
          sample / 120,
        );
        if (_distanceToSegment(position, previous, point) <= 4) return true;
        previous = point;
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant _RelationshipEdgesPainter oldDelegate) {
    return oldDelegate.focusedEdgeIds != focusedEdgeIds ||
        oldDelegate.edges != edges ||
        oldDelegate.geometries != geometries ||
        oldDelegate.selectedEdgeId != selectedEdgeId ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _RelationshipTargetDialog extends StatefulWidget {
  final String initialPerson;
  final List<String> options;
  const _RelationshipTargetDialog({
    required this.initialPerson,
    required this.options,
  });
  @override
  State<_RelationshipTargetDialog> createState() =>
      _RelationshipTargetDialogState();
}

class _RelationshipTargetDialogState extends State<_RelationshipTargetDialog> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initialPerson,
  );
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text("修正此方向的目標人物"),
    content: SizedBox(
      width: 360,
      child: AppComboBoxField(
        key: const ValueKey("relationship-repair-target"),
        controller: _input,
        labelText: "目標人物",
        options: widget.options,
        hintText: "選擇現有人物；內外關係將一起移至該人物",
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("取消"),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _input.text.trim()),
        child: const Text("儲存"),
      ),
    ],
  );
}
