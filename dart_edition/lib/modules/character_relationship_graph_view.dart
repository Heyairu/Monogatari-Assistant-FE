import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/character_data.dart";
import "../presentation/providers/project_state_providers.dart";
import "../ui_library/dialogs.dart";
import "character_relationship_editor.dart";
import "character_relationship_graph_controller.dart";
import "character_relationship_graph_mapper.dart";
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

enum _CharacterLayoutLane {
  other,
  secondarySupporting,
  importantSupporting,
  protagonist,
  mainVillain,
  secondaryVillain,
}

class _EdgeLabelPlacement {
  final Offset center;
  final Size size;

  const _EdgeLabelPlacement({required this.center, required this.size});
}

class _EdgeVisualLayout {
  final _EdgeGeometry geometry;
  final _EdgeLabelPlacement label;

  const _EdgeVisualLayout({required this.geometry, required this.label});
}

class _RadialLayoutMetrics {
  final Size canvasSize;
  final double resolvedHeight;
  final Offset protagonistCenter;
  final Offset villainCenter;
  final Map<_CharacterLayoutLane, double> radii;

  const _RadialLayoutMetrics({
    required this.canvasSize,
    required this.resolvedHeight,
    required this.protagonistCenter,
    required this.villainCenter,
    required this.radii,
  });
}

class _CharacterRelationshipGraphViewState
    extends ConsumerState<CharacterRelationshipGraphView> {
  static const _mapper = CharacterRelationshipGraphMapper();
  static const Size _nodeSize = Size.square(104);
  late final CharacterRelationshipGraphController _controller;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Size _viewportSize = Size.zero;
  bool _toolbarExpanded = true;
  bool _initialGlobalPreviewScheduled = false;

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
    _controller
      ..setNeighborsOnly(false)
      ..clearSelection();
    _initialGlobalPreviewScheduled = false;
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
    final characters = ref.watch(characterDataProvider);
    final graph = _mapper.map(characters);
    _discardMissingSelection(graph);

    if (characters.isEmpty) {
      return _buildNoCharactersState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(characters, graph),
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
        padding: const EdgeInsets.all(24),
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
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                const Icon(Icons.build_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "關係圖工具列",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: const ValueKey("relationship-toolbar-toggle"),
                  tooltip: _toolbarExpanded ? "收合工具列" : "完整展開工具列",
                  onPressed: () {
                    setState(() => _toolbarExpanded = !_toolbarExpanded);
                  },
                  icon: Icon(
                    _toolbarExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !_toolbarExpanded
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          spacing: 6,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: constraints.maxWidth,
                              child: RawAutocomplete<String>(
                                textEditingController: _searchController,
                                focusNode: _searchFocusNode,
                                optionsBuilder: (textEditingValue) =>
                                    _buildSearchOptions(
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
                                      key: const ValueKey(
                                        "relationship-search-field",
                                      ),
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        prefixIcon: const Icon(
                                          Icons.person_search_outlined,
                                        ),
                                        hintText: "搜尋或選擇人物",
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_searchController
                                                .text
                                                .isNotEmpty)
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
                                              onPressed: () =>
                                                  _focusFirstSearchResult(
                                                    characters,
                                                    graph,
                                                  ),
                                              icon: const Icon(
                                                Icons.center_focus_strong,
                                              ),
                                            ),
                                          ],
                                        ),
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                      onSubmitted: (_) {
                                        onFieldSubmitted();
                                        _focusFirstSearchResult(
                                          characters,
                                          graph,
                                        );
                                      },
                                    ),
                                optionsViewBuilder:
                                    (context, onSelected, options) => Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(8),
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
                                                final option = options
                                                    .elementAt(index);
                                                return ListTile(
                                                  key: ValueKey(
                                                    "relationship-search-option-$option",
                                                  ),
                                                  dense: true,
                                                  leading: const Icon(
                                                    Icons.person_outline,
                                                  ),
                                                  title: Text(option),
                                                  onTap: () =>
                                                      onSelected(option),
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
                              key: const ValueKey(
                                "neighbors-only-toggle-button",
                              ),
                              tooltip: "只顯示一階鄰居",
                              isSelected: _controller.neighborsOnly,
                              style: _controller.neighborsOnly
                                  ? IconButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    )
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
                              onPressed: () =>
                                  _showGlobalPreview(graph, _viewportSize),
                              icon: const Icon(Icons.fit_screen_outlined),
                            ),
                            IconButton(
                              tooltip: "新增關係",
                              onPressed: () => _addRelationship(characters),
                              icon: const Icon(Icons.add_link),
                            ),
                            IconButton(
                              tooltip: "自動重新排列",
                              onPressed: _controller.rearrange,
                              icon: const Icon(Icons.auto_fix_high_outlined),
                            ),
                            IconButton(
                              tooltip: "重設縮放",
                              onPressed: _controller.resetZoom,
                              icon: const Icon(Icons.refresh),
                            ),
                            IconButton(
                              tooltip: "縮小",
                              onPressed: () =>
                                  _controller.zoomBy(0.8, _viewportSize),
                              icon: const Icon(Icons.zoom_out),
                            ),
                            IconButton(
                              tooltip: "放大",
                              onPressed: () =>
                                  _controller.zoomBy(1.25, _viewportSize),
                              icon: const Icon(Icons.zoom_in),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
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
    final edgeVisualLayouts = _edgeVisualLayouts(
      visibleEdges,
      positions,
      canvasSize,
    );
    final connectedIds = _connectedNodeIds(graph, _controller.selectedNodeId);

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: InteractiveViewer(
              transformationController: _controller.transformationController,
              constrained: false,
              minScale: 0.2,
              maxScale: 3,
              boundaryMargin: const EdgeInsets.all(600),
              child: SizedBox(
                key: const ValueKey("relationship-graph-canvas"),
                width: canvasSize.width,
                height: canvasSize.height,
                child: Stack(
                  children: [
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
                            colorScheme: Theme.of(context).colorScheme,
                          ),
                        ),
                      ),
                    ),
                    for (final edge in visibleEdges)
                      _buildEdgeLabel(edge, edgeVisualLayouts[edge.id]!.label),
                    for (final node in graph.nodes)
                      if (visibleIds.contains(node.id))
                        _buildNode(node, positions[node.id]!, connectedIds),
                  ],
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
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.link_off_outlined),
                    const SizedBox(width: 10),
                    const Expanded(child: Text("目前沒有關係；可在此新增，或回到角色設定編輯。")),
                    TextButton.icon(
                      onPressed: () => _addRelationship(characters),
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
    final hasSelection = _controller.selectedNodeId != null;
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
            borderRadius: BorderRadius.circular(18),
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
          child: InkWell(
            onTap: () => _controller.selectNode(node.id),
            child: Padding(
              padding: const EdgeInsets.all(10),
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
                  const SizedBox(height: 8),
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
    _EdgeLabelPlacement placement,
  ) {
    final label = edge.description.isEmpty ? "未填描述" : edge.description;
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
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _controller.selectEdge(edge.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
            maxHeight: math.max(180, MediaQuery.sizeOf(context).height - 24),
          ),
          child: Card(
            elevation: 10,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: edge != null
                    ? _buildEdgeDetails(characters, graph, edge)
                    : _buildNodeDetails(characters, graph, node!),
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
              onPressed: () => _showGlobalPreview(graph, _viewportSize),
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () =>
                  _addRelationship(characters, sourceCharacterId: node.id),
              icon: const Icon(Icons.add_link),
              label: const Text("新增關係"),
            ),
            OutlinedButton.icon(
              onPressed: () => _createTargetFromNode(node.id),
              icon: const Icon(Icons.person_add_alt),
              label: const Text("建立目標人物"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEdgeDetails(
    Map<String, CharacterEntryData> characters,
    CharacterRelationshipGraphData graph,
    CharacterRelationshipGraphEdge edge,
  ) {
    final source = graph.nodeById(edge.sourceCharacterId);
    final target = graph.nodeById(edge.targetNodeId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "${source?.label ?? edge.sourceCharacterId} ${edge.isBidirectional ? '↔' : '→'} ${target?.label ?? edge.rawTargetPerson}",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: "關閉",
              onPressed: () => _showGlobalPreview(graph, _viewportSize),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(edge.description.isEmpty ? "尚未填寫關係描述" : edge.description),
        if (!edge.isResolved) ...[
          const SizedBox(height: 8),
          Text(
            edge.resolutionKind == CharacterRelationshipResolutionKind.ambiguous
                ? "有多位同名人物，請編輯並選擇含 NanoID 的人物。"
                : "找不到對應人物，可修正名稱或建立新人物。",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _editRelationship(characters, edge),
              icon: const Icon(Icons.edit_outlined),
              label: const Text("編輯"),
            ),
            if (edge.resolutionKind ==
                CharacterRelationshipResolutionKind.unresolved)
              OutlinedButton.icon(
                onPressed: () => _createCharacterForEdge(edge),
                icon: const Icon(Icons.person_add_alt),
                label: const Text("建立人物"),
              ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _deleteRelationship(edge),
              icon: const Icon(Icons.delete_outline),
              label: const Text("刪除"),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addRelationship(
    Map<String, CharacterEntryData> characters, {
    String? sourceCharacterId,
  }) async {
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
    if (result == null || !mounted) return;
    _writeRelationship(result);
  }

  Future<void> _editRelationship(
    Map<String, CharacterEntryData> characters,
    CharacterRelationshipGraphEdge edge,
  ) async {
    final result = await CharacterRelationshipEditor.show(
      context: context,
      characters: characters,
      sourceCharacterId: edge.sourceCharacterId,
      initialPerson: edge.rawTargetPerson,
      initialDescription: edge.description,
      allowSourceSelection: false,
      allowBidirectional: false,
      title: "編輯人物關係",
    );
    if (result == null || !mounted) return;
    _writeRelationship(result, editingEdge: edge);
    _controller.clearSelection();
  }

  void _writeRelationship(
    CharacterRelationshipEditorResult result, {
    CharacterRelationshipGraphEdge? editingEdge,
  }) {
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
    final editingIndex = editingEdge == null
        ? null
        : _findRelationshipIndex(source.relationships, editingEdge);
    next[result.sourceCharacterId] = source.copyWith(
      relationships: upsertCharacterRelationship(
        relationships: source.relationships,
        person: targetLabel,
        description: result.description,
        editingIndex: editingIndex,
      ),
    );

    final preserveBidirectionalPair = editingEdge?.isBidirectional ?? false;
    final writeReverse = result.bidirectional || preserveBidirectionalPair;
    if (preserveBidirectionalPair &&
        editingEdge!.targetNodeId != targetCharacterId) {
      final oldTarget = next[editingEdge.targetNodeId];
      final reverseIndex = editingEdge.reverseRelationshipIndex;
      if (oldTarget != null &&
          reverseIndex != null &&
          reverseIndex >= 0 &&
          reverseIndex < oldTarget.relationships.length) {
        final relationships =
            oldTarget.relationships.map((item) => item.copyWith()).toList()
              ..removeAt(reverseIndex);
        next[editingEdge.targetNodeId] = oldTarget.copyWith(
          relationships: relationships,
        );
      }
    }

    if (writeReverse && targetCharacterId != result.sourceCharacterId) {
      final target = next[targetCharacterId]!;
      final sourceLabel = CharacterRelationshipResolver.displayLabel(
        result.sourceCharacterId,
        next,
      );
      final reverseEditingIndex =
          preserveBidirectionalPair &&
              editingEdge!.targetNodeId == targetCharacterId
          ? editingEdge.reverseRelationshipIndex
          : null;
      next[targetCharacterId] = target.copyWith(
        relationships: upsertCharacterRelationship(
          relationships: target.relationships,
          person: sourceLabel,
          description: result.description,
          editingIndex: reverseEditingIndex,
        ),
      );
    }

    ref.read(characterDataProvider.notifier).setCharacterData(next);
  }

  int _findRelationshipIndex(
    List<CharacterRelationship> relationships,
    CharacterRelationshipGraphEdge edge,
  ) {
    final person = edge.rawTargetPerson.trim().toLowerCase();
    final exact = relationships.indexWhere(
      (item) =>
          item.person.trim().toLowerCase() == person &&
          item.relationship.trim() == edge.description,
    );
    if (exact >= 0) return exact;
    return relationships.indexWhere(
      (item) => item.person.trim().toLowerCase() == person,
    );
  }

  Future<void> _deleteRelationship(CharacterRelationshipGraphEdge edge) async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: "刪除人物關係",
      message:
          "確定要刪除「${edge.description.isEmpty ? edge.rawTargetPerson : edge.description}」嗎？",
      confirmLabel: "刪除",
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!confirmed || !mounted) return;
    final characters = Map<String, CharacterEntryData>.of(
      ref.read(characterDataProvider),
    );
    final source = characters[edge.sourceCharacterId];
    if (source != null) {
      final index = _findRelationshipIndex(source.relationships, edge);
      if (index >= 0) {
        final relationships =
            source.relationships.map((item) => item.copyWith()).toList()
              ..removeAt(index);
        characters[edge.sourceCharacterId] = source.copyWith(
          relationships: relationships,
        );
      }
    }
    if (edge.isBidirectional) {
      final target = characters[edge.targetNodeId];
      final reverseIndex = edge.reverseRelationshipIndex;
      if (target != null &&
          reverseIndex != null &&
          reverseIndex >= 0 &&
          reverseIndex < target.relationships.length) {
        final relationships =
            target.relationships.map((item) => item.copyWith()).toList()
              ..removeAt(reverseIndex);
        characters[edge.targetNodeId] = target.copyWith(
          relationships: relationships,
        );
      }
    }
    ref.read(characterDataProvider.notifier).setCharacterData(characters);
    _controller.clearSelection();
  }

  Future<void> _createCharacterForEdge(
    CharacterRelationshipGraphEdge edge,
  ) async {
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
    if (name == null || !mounted) return;
    final entry = CharacterEntryData.withName(name);
    ref
        .read(characterDataProvider.notifier)
        .setCharacterEntry(characterId: entry.characterId, entry: entry);
    if (name.trim().toLowerCase() != rawName.toLowerCase()) {
      _writeRelationship(
        CharacterRelationshipEditorResult(
          sourceCharacterId: edge.sourceCharacterId,
          person: name,
          description: edge.description,
        ),
        editingEdge: edge,
      );
    }
    _controller.selectNode(entry.characterId);
  }

  Future<void> _createTargetFromNode(String sourceCharacterId) async {
    final name = await AppDialog.prompt(
      context: context,
      title: "建立目標人物",
      message: "新人物建立後，會同時新增由目前人物指向他的關係。",
      labelText: "人物名稱",
      confirmLabel: "下一步",
      icon: Icons.person_add_alt,
    );
    if (name == null || !mounted) return;
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
    if (result != null && mounted) _writeRelationship(result);
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
    final label = edge.description.isEmpty ? "未填描述" : edge.description;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      maxLines: 2,
      ellipsis: "…",
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: 190);
    final warningWidth = edge.isResolved ? 0.0 : 18.0;
    return Size(
      (painter.width + 16 + warningWidth).clamp(56.0, 224.0),
      (painter.height + 10).clamp(30.0, 56.0),
    );
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

  Map<String, _EdgeVisualLayout> _edgeVisualLayouts(
    List<CharacterRelationshipGraphEdge> edges,
    Map<String, Offset> positions,
    Size canvasSize,
  ) {
    final nodeRects = {
      for (final entry in positions.entries)
        entry.key: Rect.fromLTWH(
          entry.value.dx,
          entry.value.dy,
          _nodeSize.width,
          _nodeSize.height,
        ),
    };
    final labelNodeObstacles = nodeRects.values
        .map((rect) => rect.inflate(34))
        .toList(growable: false);
    final occupiedLabels = <Rect>[];
    final result = <String, _EdgeVisualLayout>{};

    double overlapArea(Rect candidate, Iterable<Rect> obstacles) {
      var area = 0.0;
      for (final obstacle in obstacles) {
        final intersection = candidate.intersect(obstacle);
        if (intersection.width > 0 && intersection.height > 0) {
          area += intersection.width * intersection.height;
        }
      }
      return area;
    }

    for (final edge in edges) {
      final baseGeometry = _edgeGeometry(
        edge,
        edges,
        positions,
        nodeSize: _nodeSize,
      );
      final routeObstacles = nodeRects.entries
          .where(
            (entry) =>
                entry.key != edge.sourceCharacterId &&
                entry.key != edge.targetNodeId,
          )
          .map((entry) => entry.value.inflate(16))
          .toList(growable: false);
      final routeDelta = baseGeometry.end - baseGeometry.start;
      final routeDistance = math.max(1.0, routeDelta.distance);
      final routeNormal = Offset(
        -routeDelta.dy / routeDistance,
        routeDelta.dx / routeDistance,
      );
      final nodeCenterOffset = Offset(
        _nodeSize.width / 2,
        _nodeSize.height / 2,
      );
      final sourceCenter =
          (positions[edge.sourceCharacterId] ?? Offset.zero) + nodeCenterOffset;
      final targetCenter =
          (positions[edge.targetNodeId] ?? Offset.zero) + nodeCenterOffset;
      final maximumDetour = math.max(
        288.0,
        math.max(canvasSize.width, canvasSize.height) * 0.65,
      );
      final controlOffsets = <double>[0];
      for (var offset = 72.0; offset <= maximumDetour; offset += 72) {
        controlOffsets.addAll([offset, -offset]);
      }
      _EdgeGeometry? geometry;
      var routeScore = double.infinity;
      for (final controlOffset in controlOffsets) {
        final control = baseGeometry.control + routeNormal * controlOffset;
        final candidateStart =
            sourceCenter +
            _nodeBoundaryOffset(control - sourceCenter, _nodeSize);
        final candidateEnd =
            targetCenter +
            _nodeBoundaryOffset(control - targetCenter, _nodeSize);
        final estimatedLength =
            (candidateStart - control).distance +
            (candidateEnd - control).distance;
        final sampleCount = math.max(28, (estimatedLength / 12).ceil());
        var nodeCollisionSamples = 0;
        var labelCollisionSamples = 0;
        var boundarySamples = 0;
        for (var sample = 1; sample < sampleCount; sample++) {
          final point = _quadraticPoint(
            candidateStart,
            control,
            candidateEnd,
            sample / sampleCount,
          );
          if (routeObstacles.any((obstacle) => obstacle.contains(point))) {
            nodeCollisionSamples++;
          }
          if (occupiedLabels.any((label) => label.contains(point))) {
            labelCollisionSamples++;
          }
          if (point.dx < 8 ||
              point.dy < 8 ||
              point.dx > canvasSize.width - 8 ||
              point.dy > canvasSize.height - 8) {
            boundarySamples++;
          }
        }
        final score =
            boundarySamples * 1000000000 +
            nodeCollisionSamples * 100000000 +
            labelCollisionSamples * 1000000 +
            controlOffset.abs() * 0.02;
        if (score >= routeScore) continue;
        routeScore = score;
        geometry = _EdgeGeometry(
          start: candidateStart,
          control: control,
          end: candidateEnd,
          label: _quadraticPoint(candidateStart, control, candidateEnd, 0.5),
        );
      }
      geometry ??= baseGeometry;

      final labelSize = _edgeLabelSizeFor(edge);
      final reverseExists = edges.any(
        (candidate) =>
            candidate.sourceCharacterId == edge.targetNodeId &&
            candidate.targetNodeId == edge.sourceCharacterId,
      );
      final preferredT = reverseExists ? 0.34 : 0.5;
      final candidateTs =
          <double>[
            preferredT,
            for (var step = 4; step <= 21; step++) step / 25,
          ]..sort(
            (left, right) =>
                (left - preferredT).abs().compareTo((right - preferredT).abs()),
          );
      Offset? selectedCenter;
      var selectedScore = double.infinity;

      for (final t in candidateTs) {
        final center = _quadraticPoint(
          geometry.start,
          geometry.control,
          geometry.end,
          t,
        );
        final candidate = Rect.fromCenter(
          center: center,
          width: labelSize.width,
          height: labelSize.height,
        );
        var boundaryPenalty = 0.0;
        if (candidate.left < 8) boundaryPenalty += (8 - candidate.left) * 100;
        if (candidate.top < 8) boundaryPenalty += (8 - candidate.top) * 100;
        if (candidate.right > canvasSize.width - 8) {
          boundaryPenalty += (candidate.right - canvasSize.width + 8) * 100;
        }
        if (candidate.bottom > canvasSize.height - 8) {
          boundaryPenalty += (candidate.bottom - canvasSize.height + 8) * 100;
        }
        final score =
            overlapArea(candidate, labelNodeObstacles) * 4 +
            overlapArea(candidate, occupiedLabels) * 8 +
            boundaryPenalty +
            (t - preferredT).abs() * 4;
        if (score < selectedScore) {
          selectedScore = score;
          selectedCenter = center;
        }
      }

      final center = selectedCenter ?? geometry.label;
      final label = _EdgeLabelPlacement(center: center, size: labelSize);
      result[edge.id] = _EdgeVisualLayout(geometry: geometry, label: label);
      occupiedLabels.add(
        Rect.fromCenter(
          center: center,
          width: labelSize.width,
          height: labelSize.height,
        ).inflate(5),
      );
    }
    return result;
  }

  _CharacterLayoutLane _layoutLane(CharacterRelationshipGraphNode node) {
    return switch (node.character?.characterType.trim()) {
      "主角" => _CharacterLayoutLane.protagonist,
      "重要配角" => _CharacterLayoutLane.importantSupporting,
      "主要反派" => _CharacterLayoutLane.mainVillain,
      "次要反派" => _CharacterLayoutLane.secondaryVillain,
      "其他" => _CharacterLayoutLane.other,
      _ => _CharacterLayoutLane.secondarySupporting,
    };
  }

  String _organizationSortKey(CharacterRelationshipGraphNode node) {
    final organizations = node.character?.organizations ?? const [];
    for (final organization in organizations) {
      final name = organization.name.trim();
      if (name.isNotEmpty) return name.toLowerCase();
    }
    return "~${node.label.toLowerCase()}";
  }

  String _layoutOrganizationKey(CharacterRelationshipGraphNode node) {
    final organizations = node.character?.organizations ?? const [];
    for (final organization in organizations) {
      final name = organization.name.trim().toLowerCase();
      if (name.isNotEmpty) return "organization:$name";
    }
    return "unaffiliated";
  }

  Map<_CharacterLayoutLane, List<CharacterRelationshipGraphNode>> _nodesByLane(
    Iterable<CharacterRelationshipGraphNode> nodes,
  ) {
    final lanes = <_CharacterLayoutLane, List<CharacterRelationshipGraphNode>>{
      for (final lane in _CharacterLayoutLane.values)
        lane: <CharacterRelationshipGraphNode>[],
    };
    for (final node in nodes) {
      if (!node.isUnresolved) lanes[_layoutLane(node)]!.add(node);
    }
    for (final laneNodes in lanes.values) {
      laneNodes.sort((left, right) {
        final organizationOrder = _organizationSortKey(
          left,
        ).compareTo(_organizationSortKey(right));
        if (organizationOrder != 0) return organizationOrder;
        return left.label.toLowerCase().compareTo(right.label.toLowerCase());
      });
      if (laneNodes.isNotEmpty) {
        final shift = _controller.layoutRevision % laneNodes.length;
        laneNodes.addAll(laneNodes.take(shift));
        laneNodes.removeRange(0, shift);
      }
    }
    return lanes;
  }

  Size _canvasSize(
    CharacterRelationshipGraphData graph,
    Set<String> visibleIds,
  ) {
    final visibleNodes = graph.nodes
        .where((node) => visibleIds.contains(node.id))
        .toList(growable: false);
    return _radialLayoutMetrics(visibleNodes).canvasSize;
  }

  double _ringRadius(
    int nodeCount, {
    required double minimum,
    bool allowSingleAtCenter = false,
  }) {
    if (nodeCount == 0) return 0;
    if (allowSingleAtCenter && nodeCount == 1) return 0;
    final minimumArc = _nodeSize.width + 36;
    return math.max(minimum, nodeCount * minimumArc / (2 * math.pi));
  }

  _RadialLayoutMetrics _radialLayoutMetrics(
    List<CharacterRelationshipGraphNode> visibleNodes,
  ) {
    final lanes = _nodesByLane(visibleNodes);
    final protagonistRadius = _ringRadius(
      lanes[_CharacterLayoutLane.protagonist]!.length,
      minimum: 82,
      allowSingleAtCenter: true,
    );
    final importantRadius = _ringRadius(
      lanes[_CharacterLayoutLane.importantSupporting]!.length,
      minimum: math.max(220, protagonistRadius + 180),
    );
    final secondaryRadius = _ringRadius(
      lanes[_CharacterLayoutLane.secondarySupporting]!.length,
      minimum: math.max(400, importantRadius + 180),
    );
    final otherRadius = _ringRadius(
      lanes[_CharacterLayoutLane.other]!.length,
      minimum: math.max(570, secondaryRadius + 170),
    );
    final mainVillainRadius = _ringRadius(
      lanes[_CharacterLayoutLane.mainVillain]!.length,
      minimum: 82,
      allowSingleAtCenter: true,
    );
    final secondaryVillainRadius = _ringRadius(
      lanes[_CharacterLayoutLane.secondaryVillain]!.length,
      minimum: math.max(250, mainVillainRadius + 180),
    );
    final radii = <_CharacterLayoutLane, double>{
      _CharacterLayoutLane.protagonist: protagonistRadius,
      _CharacterLayoutLane.importantSupporting: importantRadius,
      _CharacterLayoutLane.secondarySupporting: secondaryRadius,
      _CharacterLayoutLane.other: otherRadius,
      _CharacterLayoutLane.mainVillain: mainVillainRadius,
      _CharacterLayoutLane.secondaryVillain: secondaryVillainRadius,
    };

    double maximumRadius(Iterable<_CharacterLayoutLane> clusterLanes) {
      var result = 0.0;
      for (final lane in clusterLanes) {
        if (lanes[lane]!.isNotEmpty) result = math.max(result, radii[lane]!);
      }
      return result;
    }

    final protagonistExtent = math.max(
      310.0,
      maximumRadius(const [
            _CharacterLayoutLane.protagonist,
            _CharacterLayoutLane.importantSupporting,
            _CharacterLayoutLane.secondarySupporting,
            _CharacterLayoutLane.other,
          ]) +
          _nodeSize.width / 2 +
          64,
    );
    final villainExtent = math.max(
      310.0,
      maximumRadius(const [
            _CharacterLayoutLane.mainVillain,
            _CharacterLayoutLane.secondaryVillain,
          ]) +
          _nodeSize.width / 2 +
          64,
    );
    const clusterGap = 180.0;
    final rawWidth = protagonistExtent * 2 + clusterGap + villainExtent * 2;
    final canvasWidth = math.max(1800.0, rawWidth);
    final horizontalInset = (canvasWidth - rawWidth) / 2;
    final resolvedHeight = math.max(
      820.0,
      math.max(protagonistExtent, villainExtent) * 2,
    );
    final protagonistCenter = Offset(
      horizontalInset + protagonistExtent,
      resolvedHeight / 2,
    );
    final villainCenter = Offset(
      horizontalInset + protagonistExtent * 2 + clusterGap + villainExtent,
      resolvedHeight / 2,
    );

    final unresolvedCount = visibleNodes
        .where((node) => node.isUnresolved)
        .length;
    final unresolvedColumns = math.max(
      1,
      ((canvasWidth - 48) / (_nodeSize.width + 28)).floor(),
    );
    final unresolvedRows = (unresolvedCount / unresolvedColumns).ceil();
    final unresolvedHeight = unresolvedRows == 0
        ? 0.0
        : unresolvedRows * (_nodeSize.height + 24) + 28;

    return _RadialLayoutMetrics(
      canvasSize: Size(canvasWidth, resolvedHeight + unresolvedHeight),
      resolvedHeight: resolvedHeight,
      protagonistCenter: protagonistCenter,
      villainCenter: villainCenter,
      radii: radii,
    );
  }

  Map<String, Offset> _layoutNodes(
    CharacterRelationshipGraphData graph,
    Set<String> visibleIds,
  ) {
    final visibleNodes = graph.nodes
        .where((node) => visibleIds.contains(node.id))
        .toList(growable: false);
    if (visibleNodes.isEmpty) return const {};
    final lanes = _nodesByLane(visibleNodes);
    final metrics = _radialLayoutMetrics(visibleNodes);
    final canvasSize = metrics.canvasSize;
    final unresolved = visibleNodes.where((node) => node.isUnresolved).toList();
    final positions = <String, Offset>{};
    final connectionCounts = <String, int>{};
    for (final edge in graph.edges) {
      if (!visibleIds.contains(edge.sourceCharacterId) ||
          !visibleIds.contains(edge.targetNodeId)) {
        continue;
      }
      connectionCounts[edge.sourceCharacterId] =
          (connectionCounts[edge.sourceCharacterId] ?? 0) + 1;
      connectionCounts[edge.targetNodeId] =
          (connectionCounts[edge.targetNodeId] ?? 0) + 1;
    }
    final unresolvedColumns = math.max(
      1,
      ((canvasSize.width - 48) / (_nodeSize.width + 28)).floor(),
    );

    Map<String, double> organizationAnglesFor(
      List<_CharacterLayoutLane> clusterLanes,
      double startAngle,
    ) {
      final groupedNodes = <String, List<CharacterRelationshipGraphNode>>{};
      for (final lane in clusterLanes) {
        if ((metrics.radii[lane] ?? 0) <= 0) continue;
        for (final node in lanes[lane]!) {
          groupedNodes
              .putIfAbsent(
                _layoutOrganizationKey(node),
                () => <CharacterRelationshipGraphNode>[],
              )
              .add(node);
        }
      }
      if (groupedNodes.isEmpty) return const {};
      if (groupedNodes.length == 1 &&
          groupedNodes.containsKey("unaffiliated")) {
        return const {};
      }

      final groupWeights = <String, int>{};
      for (final entry in groupedNodes.entries) {
        var maximumInLane = 1;
        for (final lane in clusterLanes) {
          maximumInLane = math.max(
            maximumInLane,
            entry.value.where((node) => _layoutLane(node) == lane).length,
          );
        }
        groupWeights[entry.key] = maximumInLane;
      }
      final orderedKeys = groupedNodes.keys.toList()
        ..sort((left, right) {
          final leftUnaffiliated = left == "unaffiliated";
          final rightUnaffiliated = right == "unaffiliated";
          if (leftUnaffiliated != rightUnaffiliated) {
            return leftUnaffiliated ? 1 : -1;
          }
          final countOrder = groupedNodes[left]!.length.compareTo(
            groupedNodes[right]!.length,
          );
          if (countOrder != 0) return countOrder;
          return left.compareTo(right);
        });
      final totalWeight = orderedKeys.fold<int>(
        0,
        (sum, key) => sum + groupWeights[key]!,
      );
      final sectorGap = orderedKeys.length <= 1
          ? 0.0
          : math.min(0.24, math.pi / (orderedKeys.length * 4));
      final availableSpan = math.max(
        math.pi,
        2 * math.pi - sectorGap * orderedKeys.length,
      );
      final result = <String, double>{};
      var cursor = startAngle;
      for (final key in orderedKeys) {
        final sectorSpan = availableSpan * groupWeights[key]! / totalWeight;
        final sectorCenter = cursor + sectorSpan / 2;
        for (final lane in clusterLanes) {
          final laneMembers = groupedNodes[key]!
              .where((node) => _layoutLane(node) == lane)
              .toList(growable: false);
          if (laneMembers.isEmpty) continue;
          final radius = metrics.radii[lane]!;
          final minimumGap = radius <= 0
              ? 0.0
              : 2 *
                    math.asin(
                      math.min(0.95, (_nodeSize.width + 18) / (2 * radius)),
                    );
          final spread = laneMembers.length <= 1
              ? 0.0
              : math.min(
                  sectorSpan * 0.68,
                  minimumGap * (laneMembers.length - 1),
                );
          for (var index = 0; index < laneMembers.length; index++) {
            final angle = laneMembers.length == 1
                ? sectorCenter
                : sectorCenter -
                      spread / 2 +
                      spread * index / (laneMembers.length - 1);
            result[laneMembers[index].id] = angle;
          }
        }
        cursor += sectorSpan + sectorGap;
      }
      return result;
    }

    final organizationAngles = <String, double>{
      ...organizationAnglesFor(const [
        _CharacterLayoutLane.protagonist,
        _CharacterLayoutLane.importantSupporting,
        _CharacterLayoutLane.secondarySupporting,
        _CharacterLayoutLane.other,
      ], -math.pi),
      ...organizationAnglesFor(const [
        _CharacterLayoutLane.mainVillain,
        _CharacterLayoutLane.secondaryVillain,
      ], -math.pi),
    };

    void placeRing(
      _CharacterLayoutLane lane,
      Offset center, {
      double startAngle = -math.pi / 2,
    }) {
      final nodes = lanes[lane]!;
      if (nodes.isEmpty) return;
      final radius = metrics.radii[lane]!;
      final angleStep = 2 * math.pi / nodes.length;
      final maximumConnections = nodes.fold<int>(
        1,
        (maximum, node) => math.max(maximum, connectionCounts[node.id] ?? 0),
      );
      for (var index = 0; index < nodes.length; index++) {
        final angle =
            organizationAngles[nodes[index].id] ??
            startAngle + index * angleStep;
        final connectionRatio =
            (connectionCounts[nodes[index].id] ?? 0) / maximumConnections;
        final relativeOffset = radius == 0
            ? Offset.zero
            : Offset.fromDirection(
                    angle + math.pi / 2,
                    8 + connectionRatio * 22,
                  ) +
                  Offset.fromDirection(angle, connectionRatio * 12);
        final nodeCenter =
            center + Offset.fromDirection(angle, radius) + relativeOffset;
        positions[nodes[index].id] =
            nodeCenter - Offset(_nodeSize.width / 2, _nodeSize.height / 2);
      }
    }

    placeRing(_CharacterLayoutLane.protagonist, metrics.protagonistCenter);
    placeRing(
      _CharacterLayoutLane.importantSupporting,
      metrics.protagonistCenter,
    );
    placeRing(
      _CharacterLayoutLane.secondarySupporting,
      metrics.protagonistCenter,
      startAngle: -math.pi / 2 + math.pi / 8,
    );
    placeRing(
      _CharacterLayoutLane.other,
      metrics.protagonistCenter,
      startAngle: math.pi / 2,
    );
    placeRing(_CharacterLayoutLane.mainVillain, metrics.villainCenter);
    placeRing(
      _CharacterLayoutLane.secondaryVillain,
      metrics.villainCenter,
      startAngle: -math.pi / 2 + math.pi / 6,
    );

    for (var index = 0; index < unresolved.length; index++) {
      final column = index % unresolvedColumns;
      final row = index ~/ unresolvedColumns;
      positions[unresolved[index].id] = Offset(
        24 + column * (_nodeSize.width + 28),
        metrics.resolvedHeight + row * (_nodeSize.height + 24) + 12,
      );
    }
    return positions;
  }
}

class _EdgeGeometry {
  final Offset start;
  final Offset control;
  final Offset end;
  final Offset label;

  const _EdgeGeometry({
    required this.start,
    required this.control,
    required this.end,
    required this.label,
  });
}

Offset _nodeBoundaryOffset(Offset direction, Size nodeSize) {
  final distance = math.max(0.0001, direction.distance);
  final normalized = direction / distance;
  final horizontalScale = normalized.dx.abs() < 0.0001
      ? double.infinity
      : nodeSize.width / 2 / normalized.dx.abs();
  final verticalScale = normalized.dy.abs() < 0.0001
      ? double.infinity
      : nodeSize.height / 2 / normalized.dy.abs();
  return normalized * math.min(horizontalScale, verticalScale);
}

_EdgeGeometry _edgeGeometry(
  CharacterRelationshipGraphEdge edge,
  List<CharacterRelationshipGraphEdge> edges,
  Map<String, Offset> positions, {
  required Size nodeSize,
}) {
  final sourceTopLeft = positions[edge.sourceCharacterId] ?? Offset.zero;
  final targetTopLeft = positions[edge.targetNodeId] ?? Offset.zero;
  final nodeCenterOffset = Offset(nodeSize.width / 2, nodeSize.height / 2);
  final source = sourceTopLeft + nodeCenterOffset;
  final target = targetTopLeft + nodeCenterOffset;
  final reverseExists = edges.any(
    (candidate) =>
        candidate.sourceCharacterId == edge.targetNodeId &&
        candidate.targetNodeId == edge.sourceCharacterId,
  );

  final centerDelta = target - source;
  final centerDistance = math.max(1.0, centerDelta.distance);
  final centerDirection = centerDelta / centerDistance;

  var start = source + _nodeBoundaryOffset(centerDirection, nodeSize);
  var end = target - _nodeBoundaryOffset(centerDirection, nodeSize);
  var bendNormal = Offset.zero;
  if (reverseExists) {
    final sourceIsCanonical =
        edge.sourceCharacterId.compareTo(edge.targetNodeId) <= 0;
    final canonicalStart = sourceIsCanonical ? source : target;
    final canonicalEnd = sourceIsCanonical ? target : source;
    final canonicalDirection =
        (canonicalEnd - canonicalStart) /
        math.max(1.0, (canonicalEnd - canonicalStart).distance);
    bendNormal = Offset(-canonicalDirection.dy, canonicalDirection.dx);

    // Keep both curves bending toward the same side while assigning each
    // direction its own parallel lane.
    const laneOffset = 32.0;
    final laneSign = sourceIsCanonical ? 1.0 : -1.0;
    final laneShift = bendNormal * (laneOffset * laneSign);
    start += laneShift;
    end += laneShift;
  }

  final midpoint = (start + end) / 2;
  final control = midpoint + bendNormal * (reverseExists ? 50.0 : 0.0);

  // Opposite directions use the same t value from their own source, placing
  // the two labels toward opposite ends instead of stacking at the midpoint.
  final label = _quadraticPoint(
    start,
    control,
    end,
    reverseExists ? 0.34 : 0.5,
  );
  return _EdgeGeometry(start: start, control: control, end: end, label: label);
}

Offset _quadraticPoint(Offset start, Offset control, Offset end, double t) {
  final inverse = 1 - t;
  return Offset(
    inverse * inverse * start.dx +
        2 * inverse * t * control.dx +
        t * t * end.dx,
    inverse * inverse * start.dy +
        2 * inverse * t * control.dy +
        t * t * end.dy,
  );
}

class _RelationshipEdgesPainter extends CustomPainter {
  final List<CharacterRelationshipGraphEdge> edges;
  final Map<String, _EdgeGeometry> geometries;
  final String? selectedEdgeId;
  final String? selectedNodeId;
  final ColorScheme colorScheme;

  const _RelationshipEdgesPainter({
    required this.edges,
    required this.geometries,
    required this.selectedEdgeId,
    required this.selectedNodeId,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final geometry = geometries[edge.id];
      if (geometry == null) continue;
      final selected = edge.id == selectedEdgeId;
      final connected =
          selectedNodeId == null ||
          edge.sourceCharacterId == selectedNodeId ||
          edge.targetNodeId == selectedNodeId;
      final color = !edge.isResolved
          ? colorScheme.error
          : selected
          ? colorScheme.secondary
          : colorScheme.outline;
      final paint = Paint()
        ..color = color.withValues(alpha: connected ? 1 : 0.22)
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
      canvas.drawPath(path, paint);

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
        final point = _quadraticPoint(
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
    return oldDelegate.edges != edges ||
        oldDelegate.geometries != geometries ||
        oldDelegate.selectedEdgeId != selectedEdgeId ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.colorScheme != colorScheme;
  }
}
