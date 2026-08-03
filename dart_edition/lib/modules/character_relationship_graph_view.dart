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

class _CharacterRelationshipGraphViewState
    extends ConsumerState<CharacterRelationshipGraphView> {
  static const _mapper = CharacterRelationshipGraphMapper();
  static const Size _nodeSize = Size(156, 72);
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
                                  ? IconButton.styleFrom(foregroundColor: Colors.green) : null,
                              onPressed: _controller.selectedNodeId == null
                                  ? null : () => _controller.setNeighborsOnly(!_controller.neighborsOnly),
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
    _controller.fitCanvas(viewportSize, _canvasSize(graph.nodes.length));
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
    final canvasSize = _canvasSize(visibleIds.length);
    final visibleEdges = graph.edges
        .where(
          (edge) =>
              visibleIds.contains(edge.sourceCharacterId) &&
              visibleIds.contains(edge.targetNodeId),
        )
        .toList(growable: false);
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
                          painter: _RelationshipEdgesPainter(
                            edges: visibleEdges,
                            positions: positions,
                            nodeSize: _nodeSize,
                            selectedEdgeId: _controller.selectedEdgeId,
                            selectedNodeId: _controller.selectedNodeId,
                            colorScheme: Theme.of(context).colorScheme,
                          ),
                        ),
                      ),
                    ),
                    for (final edge in visibleEdges)
                      _buildEdgeLabel(edge, visibleEdges, positions),
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
            borderRadius: BorderRadius.circular(14),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    node.isUnresolved
                        ? Icons.person_off_outlined
                        : Icons.person_outline,
                    color: node.isUnresolved ? scheme.error : scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
    List<CharacterRelationshipGraphEdge> edges,
    Map<String, Offset> positions,
  ) {
    final geometry = _edgeGeometry(edge, edges, positions);
    final label = edge.description.isEmpty ? "未填描述" : edge.description;
    final selected = edge.id == _controller.selectedEdgeId;
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      key: ValueKey("relationship-edge-label-${edge.id}"),
      left: geometry.label.dx - 52,
      top: geometry.label.dy - 14,
      width: 104,
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
                      maxLines: 1,
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
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: edge != null
                  ? _buildEdgeDetails(characters, graph, edge)
                  : _buildNodeDetails(characters, graph, node!),
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
                  ? null : () => widget.onOpenCharacter!(node.id),
              icon: const Icon(Icons.edit_rounded),
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
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

  Size _canvasSize(int nodeCount) {
    final columns = math.max(1, math.sqrt(math.max(1, nodeCount)).ceil());
    final rows = math.max(1, (nodeCount / columns).ceil());
    return Size(
      math.max(900, columns * 230 + 180).toDouble(),
      math.max(650, rows * 160 + 180).toDouble(),
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
    final canvasSize = _canvasSize(visibleNodes.length);
    final resolved = visibleNodes.where((node) => !node.isUnresolved).toList();
    final unresolved = visibleNodes.where((node) => node.isUnresolved).toList();
    if (resolved.isNotEmpty) {
      final shift = _controller.layoutRevision % resolved.length;
      resolved.addAll(resolved.take(shift));
      resolved.removeRange(0, shift);
    }
    final positions = <String, Offset>{};
    final unresolvedColumns = math.max(
      1,
      ((canvasSize.width - 48) / (_nodeSize.width + 28)).floor(),
    );
    final unresolvedRows = unresolved.isEmpty
        ? 0
        : (unresolved.length / unresolvedColumns).ceil();
    final unresolvedAreaHeight = unresolvedRows * (_nodeSize.height + 24);
    final resolvedAreaHeight = math.max(
      320.0,
      canvasSize.height - unresolvedAreaHeight,
    );
    if (resolved.length == 1) {
      positions[resolved.single.id] = Offset(
        canvasSize.width / 2 - _nodeSize.width / 2,
        resolvedAreaHeight / 2 - _nodeSize.height / 2,
      );
    } else if (resolved.length <= 12) {
      final radiusX = math.max(220.0, canvasSize.width / 2 - 190);
      final radiusY = math.max(110.0, resolvedAreaHeight / 2 - 90);
      for (var index = 0; index < resolved.length; index++) {
        final angle = -math.pi / 2 + (2 * math.pi * index / resolved.length);
        positions[resolved[index].id] = Offset(
          canvasSize.width / 2 +
              math.cos(angle) * radiusX -
              _nodeSize.width / 2,
          resolvedAreaHeight / 2 +
              math.sin(angle) * radiusY -
              _nodeSize.height / 2,
        );
      }
    } else {
      final columns = math.max(
        1,
        ((canvasSize.width - 100) / (_nodeSize.width + 56)).floor(),
      );
      final rows = (resolved.length / columns).ceil();
      final gridWidth =
          math.min(columns, resolved.length) * (_nodeSize.width + 56);
      final gridHeight = rows * (_nodeSize.height + 42);
      final origin = Offset(
        math.max(24, (canvasSize.width - gridWidth) / 2),
        math.max(24, (resolvedAreaHeight - gridHeight) / 2),
      );
      for (var index = 0; index < resolved.length; index++) {
        positions[resolved[index].id] = Offset(
          origin.dx + (index % columns) * (_nodeSize.width + 56),
          origin.dy + (index ~/ columns) * (_nodeSize.height + 42),
        );
      }
    }
    for (var index = 0; index < unresolved.length; index++) {
      final column = index % unresolvedColumns;
      final row = index ~/ unresolvedColumns;
      positions[unresolved[index].id] = Offset(
        24 + column * (_nodeSize.width + 28),
        canvasSize.height -
            unresolvedAreaHeight +
            row * (_nodeSize.height + 24) +
            12,
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

_EdgeGeometry _edgeGeometry(
  CharacterRelationshipGraphEdge edge,
  List<CharacterRelationshipGraphEdge> edges,
  Map<String, Offset> positions,
) {
  final sourceTopLeft = positions[edge.sourceCharacterId] ?? Offset.zero;
  final targetTopLeft = positions[edge.targetNodeId] ?? Offset.zero;
  final source = sourceTopLeft + const Offset(78, 36);
  final target = targetTopLeft + const Offset(78, 36);
  final reverseExists = edges.any(
    (candidate) =>
        candidate.sourceCharacterId == edge.targetNodeId &&
        candidate.targetNodeId == edge.sourceCharacterId,
  );

  var shiftedSource = source;
  var shiftedTarget = target;
  var bendNormal = Offset.zero;
  if (reverseExists) {
    final sourceIsCanonical =
        edge.sourceCharacterId.compareTo(edge.targetNodeId) <= 0;
    final canonicalStart = sourceIsCanonical ? source : target;
    final canonicalEnd = sourceIsCanonical ? target : source;
    final canonicalDelta = canonicalEnd - canonicalStart;
    final canonicalDistance = math.max(1.0, canonicalDelta.distance);
    final canonicalDirection = canonicalDelta / canonicalDistance;
    bendNormal = Offset(-canonicalDirection.dy, canonicalDirection.dx);

    // Keep both curves bending toward the same side while assigning each
    // direction its own parallel lane.
    const laneOffset = 14.0;
    final laneSign = sourceIsCanonical ? 1.0 : -1.0;
    final laneShift = bendNormal * (laneOffset * laneSign);
    shiftedSource += laneShift;
    shiftedTarget += laneShift;
  }

  final delta = shiftedTarget - shiftedSource;
  final distance = math.max(1.0, delta.distance);
  final direction = delta / distance;
  final start = shiftedSource + Offset(direction.dx * 80, direction.dy * 42);
  final end = shiftedTarget - Offset(direction.dx * 80, direction.dy * 42);
  final midpoint = (start + end) / 2;
  final control = midpoint + bendNormal * (reverseExists ? 42.0 : 0.0);

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
  final Map<String, Offset> positions;
  final Size nodeSize;
  final String? selectedEdgeId;
  final String? selectedNodeId;
  final ColorScheme colorScheme;

  const _RelationshipEdgesPainter({
    required this.edges,
    required this.positions,
    required this.nodeSize,
    required this.selectedEdgeId,
    required this.selectedNodeId,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final geometry = _edgeGeometry(edge, edges, positions);
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
        ..strokeWidth = selected ? 3.5 : 2;
      final path = Path()
        ..moveTo(geometry.start.dx, geometry.start.dy)
        ..quadraticBezierTo(
          geometry.control.dx,
          geometry.control.dy,
          geometry.end.dx,
          geometry.end.dy,
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

  @override
  bool shouldRepaint(covariant _RelationshipEdgesPainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.positions != positions ||
        oldDelegate.selectedEdgeId != selectedEdgeId ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.colorScheme != colorScheme;
  }
}
