import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../bin/ui_library.dart";
import "../models/chapter_selection_data.dart";
import "../models/outline_data.dart";
import "../models/timeline_data.dart";
import "../presentation/providers/project_state_providers.dart";
import "../presentation/providers/timeline_providers.dart";

typedef TimelineOpenChapter = void Function(String chapterUUID);
typedef TimelineOpenOutlineScene = void Function(String sceneUUID);

class _PendingOutlineBox {
  final StorylineData storyline;
  final bool isLargeMissing;
  final int missingEventCount;
  final int missingSceneCount;

  const _PendingOutlineBox({
    required this.storyline,
    required this.isLargeMissing,
    required this.missingEventCount,
    required this.missingSceneCount,
  });
}

enum _TimelineResizeEdge { start, end }

class _TimelineResizePreview {
  final _TimelineResizeEdge edge;
  final double pixelDelta;

  const _TimelineResizePreview(this.edge, this.pixelDelta);
}

class TimelineView extends ConsumerStatefulWidget {
  final TimelineOpenChapter? onOpenChapter;
  final TimelineOpenOutlineScene? onOpenOutlineScene;

  const TimelineView({super.key, this.onOpenChapter, this.onOpenOutlineScene});

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _timelineHorizontalScrollController =
      ScrollController();
  final Map<String, Offset> _dragOffsets = <String, Offset>{};
  final Map<String, _TimelineResizePreview> _resizePreviews =
      <String, _TimelineResizePreview>{};
  _TimelineTickAxis? _activeAxis;

  @override
  void dispose() {
    _searchController.dispose();
    _timelineHorizontalScrollController.dispose();
    super.dispose();
  }

  TimelineActions get _actions => ref.read(timelineActionsProvider);

  @override
  Widget build(BuildContext context) {
    final document = ref.watch(timelineDocumentProvider);
    final links = ref.watch(outlineChapterLinksProvider);
    final viewState = ref.watch(timelineViewProvider);
    final scenes = ref.watch(timelineSceneIndexProvider);
    final outline = ref.watch(outlineDataProvider);
    final chapters = ref.watch(timelineChapterIndexProvider);
    final editorSelection = ref.watch(editorSelectionProvider);

    final placementsById = {
      for (final placement in document.placements)
        placement.placementUUID: placement,
    };
    final scope = viewState.scopePlacementUUID == null
        ? null
        : placementsById[viewState.scopePlacementUUID];
    if (viewState.scopePlacementUUID != null && scope == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(timelineViewProvider.notifier).enterScope(null);
      });
    }
    final selected = viewState.selectedPlacementUUID == null
        ? null
        : placementsById[viewState.selectedPlacementUUID];
    final currentChapterUUID = editorSelection.selectedChapID;
    final filteredPlacements = _filteredScopePlacements(
      document: document,
      scopeUUID: scope?.placementUUID,
      state: viewState,
      scenes: scenes,
      links: links,
      currentChapterUUID: currentChapterUUID,
    );
    final scopePlacements = document.placements
        .where(
          (placement) => placement.parentPlacementUUID == scope?.placementUUID,
        )
        .toList(growable: false);
    final timelineAxis = _TimelineTickAxis.fromPlacements(
      scopePlacements,
      omitEmptyRanges: viewState.omitEmptyRanges,
      anchorTick: viewState.currentTick,
    );
    _activeAxis = timelineAxis;
    final pendingOutlineBoxes = _pendingOutlineBoxes(
      document: document,
      outline: outline,
      links: links,
      state: viewState,
      currentChapterUUID: currentChapterUUID,
    );
    final danglingCount = _danglingCount(
      document: document,
      links: links,
      scenes: scenes,
      chapters: chapters,
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LargeTitle(icon: Icons.view_timeline_outlined, text: "時間軸"),
            const SizedBox(height: 20),
            if (danglingCount > 0) ...[
              AppNoticeBanner(
                message: "偵測到 $danglingCount 筆缺失引用；資料已保留，請重新連結或移除對應節點。",
                tone: AppFeedbackTone.warning,
              ),
              const SizedBox(height: 16),
            ],
            _buildBreadcrumb(document, scope),
            const SizedBox(height: 12),
            AppTextField(
              controller: _searchController,
              labelText: "搜尋時間軸",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: "清除搜尋",
                      onPressed: () {
                        _searchController.clear();
                        ref.read(timelineViewProvider.notifier).setQuery("");
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
              onChanged: (value) {
                ref.read(timelineViewProvider.notifier).setQuery(value);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            _buildToolbar(viewState, currentChapterUUID, scope, document.grid),
            const SizedBox(height: 16),
            AppSectionCard(
              padding: EdgeInsets.zero,
              useSectionLayout: false,
              clipBehavior: Clip.antiAlias,
              child: _TimelineBoard(
                document: document,
                placements: filteredPlacements,
                scenes: scenes,
                selectedPlacementUUID: selected?.placementUUID,
                pixelsPerTick: viewState.pixelsPerTick,
                axis: timelineAxis,
                currentTick: viewState.currentTick,
                horizontalScrollController: _timelineHorizontalScrollController,
                dragOffsets: _dragOffsets,
                resizePreviews: _resizePreviews,
                onSelect: (placementUUID) {
                  ref.read(timelineViewProvider.notifier).select(placementUUID);
                },
                onEnter: _enterPlacement,
                onDragPreview: (placementUUID, delta) {
                  setState(() => _dragOffsets[placementUUID] = delta);
                },
                onMove: _movePlacementByPixels,
                onResizePreview: (placementUUID, edge, delta) {
                  setState(() {
                    _resizePreviews[placementUUID] = _TimelineResizePreview(
                      edge,
                      delta,
                    );
                  });
                },
                onResize: _resizePlacementByPixels,
                onScrub: _updateCurrentTickFromScrubber,
                onAddTrack: _addTrack,
                onTrackAction: _handleTrackAction,
              ),
            ),
            const SizedBox(height: 16),
            _buildViewportControls(viewState),
            const SizedBox(height: 16),
            _TimelineInspector(
              placement: selected,
              document: document,
              scenes: scenes,
              chapters: chapters,
              links: links,
              onUpdate: _updatePlacement,
              onDelete: _deletePlacement,
              onAddChapterLink: _showChapterLinkDialog,
              onRemoveChapterLink: (placement, chapterUUID) =>
                  _actions.removeChapterLinkFromPlacement(
                    placement.placementUUID,
                    chapterUUID,
                  ),
              onOpenChapter: widget.onOpenChapter,
              onOpenOutlineScene: widget.onOpenOutlineScene,
            ),
            const SizedBox(height: 16),
            _buildPendingOutlineBoxes(pendingOutlineBoxes),
            const SizedBox(height: 16),
            _buildGridSettings(document.grid),
          ],
        ),
      ),
    );
  }

  List<TimelinePlacementData> _filteredScopePlacements({
    required TimelineDocumentData document,
    required String? scopeUUID,
    required TimelineViewState state,
    required Map<String, TimelineSceneReference> scenes,
    required List<OutlineChapterLinkData> links,
    required String? currentChapterUUID,
  }) {
    final query = state.query.trim().toLowerCase();
    return document.placements
        .where((placement) {
          if (placement.parentPlacementUUID != scopeUUID) return false;
          final scene = placement.sceneUUID == null
              ? null
              : scenes[placement.sceneUUID];
          final sceneUUIDs = timelineSceneUUIDsForPlacement(
            document,
            placement.placementUUID,
          );
          final sceneLinks = links
              .where((link) => sceneUUIDs.contains(link.sceneUUID))
              .toList(growable: false);
          if (state.onlyCurrentChapter &&
              (currentChapterUUID == null ||
                  !sceneLinks.any(
                    (link) => link.chapterUUID == currentChapterUUID,
                  ))) {
            return false;
          }
          final hasUnlinkedScene = sceneUUIDs.any(
            (sceneUUID) =>
                !sceneLinks.any((link) => link.sceneUUID == sceneUUID),
          );
          if (state.onlyUnlinked && (sceneUUIDs.isEmpty || !hasUnlinkedScene)) {
            return false;
          }
          if (query.isNotEmpty) {
            final haystack = [
              placement.label,
              scene?.scene.sceneName ?? "",
              scene?.event.storyEvent ?? "",
              scene?.storyline.storylineName ?? "",
              scene?.scene.location ?? "",
            ].join(" ").toLowerCase();
            if (!haystack.contains(query)) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<_PendingOutlineBox> _pendingOutlineBoxes({
    required TimelineDocumentData document,
    required List<StorylineData> outline,
    required List<OutlineChapterLinkData> links,
    required TimelineViewState state,
    required String? currentChapterUUID,
  }) {
    final placedSceneUUIDs = document.placements
        .map((placement) => placement.sceneUUID)
        .whereType<String>()
        .toSet();
    final query = state.query.trim().toLowerCase();
    final result = <_PendingOutlineBox>[];
    for (final storyline in outline) {
      final large = document.placements.where((placement) {
        return placement.level == TimelineElementLevel.large &&
            placement.parentPlacementUUID == null &&
            placement.storylineUUID == storyline.chapterUUID;
      }).firstOrNull;
      var missingEventCount = 0;
      final missingScenes = <SceneData>[];
      for (final event in storyline.scenes) {
        final hasMiddle =
            large != null &&
            document.placements.any(
              (placement) =>
                  placement.level == TimelineElementLevel.middle &&
                  placement.parentPlacementUUID == large.placementUUID &&
                  placement.eventUUID == event.storyEventUUID,
            );
        if (!hasMiddle) missingEventCount++;
        missingScenes.addAll(
          event.scenes.where(
            (scene) => !placedSceneUUIDs.contains(scene.sceneUUID),
          ),
        );
      }
      if (large != null && missingEventCount == 0 && missingScenes.isEmpty) {
        continue;
      }
      if (state.onlyCurrentChapter) {
        if (currentChapterUUID == null ||
            !missingScenes.any(
              (scene) => links.any(
                (link) =>
                    link.sceneUUID == scene.sceneUUID &&
                    link.chapterUUID == currentChapterUUID,
              ),
            )) {
          continue;
        }
      }
      if (state.onlyUnlinked &&
          !missingScenes.any(
            (scene) => !links.any((link) => link.sceneUUID == scene.sceneUUID),
          )) {
        continue;
      }
      if (query.isNotEmpty) {
        final haystack = <String>[
          storyline.storylineName,
          storyline.storylineType,
          for (final event in storyline.scenes) event.storyEvent,
          for (final scene in missingScenes) ...[
            scene.sceneName,
            scene.location,
            scene.time,
          ],
        ].join(" ").toLowerCase();
        if (!haystack.contains(query)) continue;
      }
      result.add(
        _PendingOutlineBox(
          storyline: storyline,
          isLargeMissing: large == null,
          missingEventCount: missingEventCount,
          missingSceneCount: missingScenes.length,
        ),
      );
    }
    return result;
  }

  int _danglingCount({
    required TimelineDocumentData document,
    required List<OutlineChapterLinkData> links,
    required Map<String, TimelineSceneReference> scenes,
    required Map<String, ChapterLocation> chapters,
  }) {
    final placementIds = document.placements
        .map((placement) => placement.placementUUID)
        .toSet();
    final trackIds = document.tracks.map((track) => track.trackUUID).toSet();
    return document.placements.where((placement) {
          return (placement.sceneUUID != null &&
                  !scenes.containsKey(placement.sceneUUID)) ||
              !trackIds.contains(placement.trackUUID) ||
              (placement.parentPlacementUUID != null &&
                  !placementIds.contains(placement.parentPlacementUUID));
        }).length +
        links.where((link) {
          return !scenes.containsKey(link.sceneUUID) ||
              !chapters.containsKey(link.chapterUUID);
        }).length;
  }

  Widget _buildBreadcrumb(
    TimelineDocumentData document,
    TimelinePlacementData? scope,
  ) {
    final byId = {
      for (final placement in document.placements)
        placement.placementUUID: placement,
    };
    final path = <TimelinePlacementData>[];
    var current = scope;
    final seen = <String>{};
    while (current != null && seen.add(current.placementUUID)) {
      path.insert(0, current);
      current = current.parentPlacementUUID == null
          ? null
          : byId[current.parentPlacementUUID];
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () =>
              ref.read(timelineViewProvider.notifier).enterScope(null),
          icon: const Icon(Icons.home_outlined, size: 18),
          label: const Text("主時間軸"),
        ),
        for (final placement in path) ...[
          const Icon(Icons.chevron_right, size: 18),
          TextButton(
            onPressed: () => ref
                .read(timelineViewProvider.notifier)
                .enterScope(placement.placementUUID),
            child: Text(_placementLabel(placement, const {})),
          ),
        ],
      ],
    );
  }

  Widget _buildToolbar(
    TimelineViewState state,
    String? currentChapterUUID,
    TimelinePlacementData? scope,
    TimelineGridConfig grid,
  ) {
    final nextLevel = switch (scope?.level) {
      null => TimelineElementLevel.large,
      TimelineElementLevel.large => TimelineElementLevel.middle,
      TimelineElementLevel.middle => TimelineElementLevel.small,
      TimelineElementLevel.small => null,
    };
    final label = switch (nextLevel) {
      TimelineElementLevel.large => "新增大箱",
      TimelineElementLevel.middle => "新增中箱",
      TimelineElementLevel.small => "新增小箱",
      null => "小箱是最末層節點",
    };
    final icon = switch (nextLevel) {
      TimelineElementLevel.large => Icons.add_home_work_rounded,
      TimelineElementLevel.middle => Icons.post_add_rounded,
      TimelineElementLevel.small => Icons.playlist_add_rounded,
      null => Icons.block,
    };
    return AppSectionCard(
      padding: const EdgeInsets.all(16),
      useSectionLayout: false,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    IconButton(
                      icon: Icon(Icons.menu_open_rounded),
                      tooltip: "只看目前章節",
                      style: state.onlyCurrentChapter
                          ? IconButton.styleFrom(
                              foregroundColor: Colors.teal[400],
                            )
                          : null,
                      isSelected: state.onlyCurrentChapter,
                      onPressed: currentChapterUUID == null
                          ? null
                          : () => ref
                                .read(timelineViewProvider.notifier)
                                .setOnlyCurrentChapter(
                                  !state.onlyCurrentChapter,
                                ),
                    ),
                    IconButton(
                      icon: Icon(Icons.link_off_rounded),
                      tooltip: "未連結章節",
                      style: state.onlyUnlinked
                          ? IconButton.styleFrom(
                              foregroundColor: Colors.teal[400],
                            )
                          : null,
                      isSelected: state.onlyUnlinked,
                      onPressed: () => ref
                          .read(timelineViewProvider.notifier)
                          .setOnlyUnlinked(!state.onlyUnlinked),
                    ),
                    IconButton(
                      key: const ValueKey("timeline-auto-sort-outline"),
                      icon: Icon(Icons.view_timeline_outlined),
                      tooltip: "自動排序大綱\n依起始 Tick、時間軌順序排列大綱；大綱順序變更時同步調整時間軸。",
                      style: grid.autoSortOutline
                          ? IconButton.styleFrom(
                              foregroundColor: Colors.teal[400],
                            )
                          : null,
                      isSelected: grid.autoSortOutline,
                      onPressed: () => _actions.updateGrid(
                        grid.copyWith(autoSortOutline: !grid.autoSortOutline),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey("timeline-omit-empty-ranges"),
                      icon: const Icon(Icons.compress_rounded),
                      tooltip: state.omitEmptyRanges
                          ? "顯示時間軸空白區段"
                          : "省略時間軸空白區段",
                      style: state.omitEmptyRanges
                          ? IconButton.styleFrom(
                              foregroundColor: Colors.teal[400],
                            )
                          : null,
                      isSelected: state.omitEmptyRanges,
                      onPressed: () => ref
                          .read(timelineViewProvider.notifier)
                          .setOmitEmptyRanges(!state.omitEmptyRanges),
                    ),
                    IconButton(
                      icon: const Icon(Icons.location_on_rounded),
                      tooltip: "返回目前時間軸",
                      hoverColor: Theme.of(context).colorScheme.primaryContainer,
                      onPressed: () => _setCurrentTick(state.currentTick),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: ValueKey("timeline-add-${nextLevel?.name ?? 'none'}"),
                icon: Icon(icon),
                tooltip: label,
                style: nextLevel == null
                    ? IconButton.styleFrom(foregroundColor: Colors.red)
                    : IconButton.styleFrom(foregroundColor: Colors.green),
                onPressed: nextLevel == null
                    ? null
                    : () => _showAddNodeDialog(
                        level: nextLevel,
                        parentUUID: scope?.placementUUID,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewportControls(TimelineViewState state) {
    final zoomSlider = IconedSlider(
      icon: Icons.zoom_in,
      value: state.pixelsPerTick,
      tooltip: "畫面 Tick 寬度",
      min: 36,
      max: 144,
      divisions: 54,
      valueLabelBuilder: (value) => "${value.round()} px",
      onChanged: ref.read(timelineViewProvider.notifier).setPixelsPerTick,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: const ValueKey("timeline-zoom-controls"),
          child: zoomSlider,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: const ValueKey("timeline-navigation-row"),
            width: 260,
            child: _NumberStepper(
              key: const ValueKey("timeline-current-tick-stepper"),
              label: "目前 Tick",
              value: state.currentTick,
              minimum: -0x3fffffff,
              allowNegative: true,
              onChanged: _setCurrentTick,
            ),
          ),
        ),
      ],
    );
  }

  void _setCurrentTick(int tick, {bool animate = true}) {
    ref.read(timelineViewProvider.notifier).setCurrentTick(tick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_timelineHorizontalScrollController.hasClients) return;
      final axis = _activeAxis;
      if (axis == null) return;
      final position = _timelineHorizontalScrollController.position;
      final pixelsPerTick = ref.read(timelineViewProvider).pixelsPerTick;
      final tickOffset = axis.displayPositionForTick(tick) * pixelsPerTick;
      final target = (tickOffset - position.viewportDimension / 2)
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      if (animate) {
        _timelineHorizontalScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _timelineHorizontalScrollController.jumpTo(target);
      }
    });
  }

  void _updateCurrentTickFromScrubber(int tick) {
    _setCurrentTick(tick, animate: false);
  }

  Widget _buildPendingOutlineBoxes(List<_PendingOutlineBox> boxes) {
    return AppSectionCard(
      title: "未排定大箱",
      icon: Icons.pending_actions_outlined,
      child: boxes.isEmpty
          ? const AppEmptyState(
              title: "所有大綱大箱皆已同步",
              icon: Icons.check_circle_outline,
              compact: true,
            )
          : Column(
              children: [
                const AppNoticeBanner(
                  message: "同步時會建立或補齊整個大箱、中箱與小箱階層，不會把單一場景放進目前中箱。",
                  tone: AppFeedbackTone.info,
                ),
                for (final box in boxes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(
                      box.storyline.storylineName.isEmpty
                          ? "未命名大箱"
                          : box.storyline.storylineName,
                    ),
                    subtitle: Text(
                      box.isLargeMissing
                          ? "時間軸大箱不存在；包含 ${box.storyline.scenes.length} 個中箱、${box.missingSceneCount} 個小箱"
                          : "待補齊 ${box.missingEventCount} 個中箱、${box.missingSceneCount} 個小箱",
                    ),
                    trailing: IconButton(
                      tooltip: "同步整個大箱",
                      onPressed: () {
                        final result = _actions.syncStorylineHierarchy(
                          box.storyline.chapterUUID,
                        );
                        if (result.message != null) {
                          AppFeedback.info(context, result.message!);
                        }
                      },
                      icon: const Icon(Icons.sync),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildGridSettings(TimelineGridConfig grid) {
    return AppSectionCard(
      title: "故事刻度設定",
      icon: Icons.straighten,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdownField<TickDurationUnit>(
            value: grid.ticksPerLittleBox.unit,
            labelText: "Tick 單位",
            options: [
              for (final unit in TickDurationUnit.values)
                DropdownOption(value: unit, label: _unitLabel(unit)),
            ],
            onChanged: (unit) {
              if (unit == null) return;
              _actions.updateGrid(
                grid.copyWith(
                  ticksPerLittleBox: grid.ticksPerLittleBox.copyWith(
                    unit: unit,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _NumberStepper(
            key: const ValueKey("timeline-tick-unit-value"),
            label: "Tick 對應單位數",
            value: grid.ticksPerLittleBox.value,
            onChanged: (value) => _actions.updateGrid(
              grid.copyWith(
                ticksPerLittleBox: grid.ticksPerLittleBox.copyWith(
                  value: value,
                ),
              ),
            ),
          ),
          _NumberStepper(
            key: const ValueKey("timeline-small-box-ticks"),
            label: "每小箱 Tick 數",
            value: grid.ticksPerSmallBox,
            onChanged: (value) =>
                _actions.updateGrid(grid.copyWith(ticksPerSmallBox: value)),
          ),
          _NumberStepper(
            label: "每中箱的小箱數",
            value: grid.ticksPerMiddleBox,
            onChanged: (value) =>
                _actions.updateGrid(grid.copyWith(ticksPerMiddleBox: value)),
          ),
          _NumberStepper(
            label: "每大箱的中箱數",
            value: grid.middleBoxesPerLargeBox,
            onChanged: (value) => _actions.updateGrid(
              grid.copyWith(middleBoxesPerLargeBox: value),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "1 Tick = ${grid.ticksPerLittleBox.value} ${_unitLabel(grid.ticksPerLittleBox.unit)}；"
            "1 小箱 = ${grid.ticksPerSmallBox} Tick；"
            "1 中箱 = ${grid.ticksPerSmallBox * grid.ticksPerMiddleBox} Tick；"
            "1 大箱 = ${grid.ticksPerSmallBox * grid.ticksPerMiddleBox * grid.middleBoxesPerLargeBox} Tick。",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddNodeDialog({
    required TimelineElementLevel level,
    required String? parentUUID,
  }) async {
    final scenes = ref.read(timelineSceneIndexProvider);
    final placedSceneUUIDs = ref
        .read(timelineDocumentProvider)
        .placements
        .map((placement) => placement.sceneUUID)
        .whereType<String>()
        .toSet();
    final availableScenes = scenes.values
        .where(
          (reference) => !placedSceneUUIDs.contains(reference.scene.sceneUUID),
        )
        .toList(growable: false);
    var label = "";
    String? selectedSceneUUID;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("新增${_levelLabel(level)}"),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  key: const ValueKey("timeline-add-node-label"),
                  labelText: "節點名稱",
                  hintText: level == TimelineElementLevel.small
                      ? "未選場景時必填"
                      : "例如：第一幕",
                  autofocus: true,
                  onChanged: (value) => label = value,
                ),
                if (level == TimelineElementLevel.middle) ...[
                  const SizedBox(height: 12),
                  const AppNoticeBanner(
                    message: "新增中箱時會同步建立對應的大綱事件。",
                    tone: AppFeedbackTone.info,
                  ),
                ],
                if (level == TimelineElementLevel.small) ...[
                  const SizedBox(height: 12),
                  AppDropdownField<String?>(
                    value: selectedSceneUUID,
                    labelText: "大綱場景（可選）",
                    options: [
                      const DropdownOption<String?>(
                        value: null,
                        label: "建立新的大綱場景",
                      ),
                      for (final reference in availableScenes)
                        DropdownOption<String?>(
                          value: reference.scene.sceneUUID,
                          label: reference.scene.sceneName.isEmpty
                              ? "未命名場景"
                              : reference.scene.sceneName,
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedSceneUUID = value),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("取消"),
            ),
            FilledButton(
              key: const ValueKey("timeline-confirm-add-node"),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("新增"),
            ),
          ],
        ),
      ),
    );
    label = label.trim();
    if (result != true) return;
    if (level == TimelineElementLevel.small &&
        selectedSceneUUID == null &&
        label.isEmpty) {
      if (mounted) AppFeedback.warning(context, "請輸入節點名稱或選擇大綱場景。");
      return;
    }
    final placement = _actions.addPlacement(
      level: level,
      parentPlacementUUID: parentUUID,
      sceneUUID: selectedSceneUUID,
      label: label,
      startTick: ref.read(timelineViewProvider).currentTick,
    );
    ref.read(timelineViewProvider.notifier).select(placement.placementUUID);
  }

  Future<void> _addTrack() async {
    final name = await AppDialog.prompt(
      context: context,
      title: "新增軌道",
      labelText: "軌道名稱",
      initialValue:
          "時間軸 ${ref.read(timelineDocumentProvider).tracks.length + 1}",
    );
    if (name == null) return;
    _actions.addTrack(name);
  }

  Future<void> _handleTrackAction(
    TimelineTrackData track,
    String action,
  ) async {
    switch (action) {
      case "rename":
        final name = await AppDialog.prompt(
          context: context,
          title: "重新命名軌道",
          initialValue: track.name,
        );
        if (name != null) _actions.renameTrack(track.trackUUID, name);
        break;
      case "toggle":
        _actions.toggleTrack(track.trackUUID);
        break;
      case "up":
        _actions.moveTrack(track.trackUUID, -1);
        break;
      case "down":
        _actions.moveTrack(track.trackUUID, 1);
        break;
      case "delete":
        final confirmed = await AppDialog.confirm(
          context: context,
          title: "刪除軌道",
          message: "軌道上的節點會移到其他軌道，不會刪除大綱場景。",
          destructive: true,
        );
        if (confirmed) {
          final result = _actions.deleteTrack(track.trackUUID);
          if (mounted && result.message != null) {
            result.changed
                ? AppFeedback.info(context, result.message!)
                : AppFeedback.warning(context, result.message!);
          }
        }
        break;
    }
  }

  void _enterPlacement(String placementUUID) {
    final document = ref.read(timelineDocumentProvider);
    final placement = document.placements
        .where((item) => item.placementUUID == placementUUID)
        .firstOrNull;
    if (placement == null) return;
    if (placement.level == TimelineElementLevel.small) {
      _openSmallPlacement(placement);
      return;
    }
    ref.read(timelineViewProvider.notifier).enterScope(placementUUID);
  }

  Future<void> _openSmallPlacement(TimelinePlacementData placement) async {
    final sceneUUID = placement.sceneUUID;
    if (sceneUUID == null) {
      if (mounted) AppFeedback.info(context, "此小箱尚未連結大綱場景。");
      return;
    }
    final chapterIndex = ref.read(timelineChapterIndexProvider);
    final validLinks =
        ref
            .read(outlineChapterLinksProvider)
            .where((link) => link.sceneUUID == sceneUUID)
            .where((link) => chapterIndex.containsKey(link.chapterUUID))
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    String? chapterUUID;
    if (validLinks.length == 1) {
      chapterUUID = validLinks.single.chapterUUID;
    } else if (validLinks.length > 1) {
      chapterUUID = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text("選擇要開啟的章節"),
          children: [
            for (final link in validLinks)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, link.chapterUUID),
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(
                    chapterIndex[link.chapterUUID]!.chapter.chapterName,
                  ),
                  subtitle: Text(
                    chapterIndex[link.chapterUUID]!.folder.segmentName,
                  ),
                ),
              ),
          ],
        ),
      );
      if (!mounted) return;
    }
    widget.onOpenOutlineScene?.call(sceneUUID);
    if (chapterUUID != null) widget.onOpenChapter?.call(chapterUUID);
    if (chapterUUID == null && mounted) {
      AppFeedback.info(context, "此場景尚未連結章節；編輯器維持目前章節。");
    }
  }

  void _movePlacementByPixels(
    TimelinePlacementData placement,
    Offset pixelDelta,
  ) {
    final pixelsPerTick = ref.read(timelineViewProvider).pixelsPerTick;
    final tickDelta = (pixelDelta.dx / pixelsPerTick).round();
    final tracks = [...ref.read(timelineDocumentProvider).tracks]
      ..sort((a, b) => a.order.compareTo(b.order));
    final visibleTracks = tracks
        .where((track) => !track.isCollapsed)
        .toList(growable: false);
    final currentTrackIndex = visibleTracks.indexWhere(
      (track) => track.trackUUID == placement.trackUUID,
    );
    final trackDelta = (pixelDelta.dy / _TimelineBoard.rowHeight).round();
    final targetTrackIndex = currentTrackIndex < 0
        ? -1
        : (currentTrackIndex + trackDelta).clamp(0, visibleTracks.length - 1);
    final targetTrackUUID = targetTrackIndex < 0
        ? placement.trackUUID
        : visibleTracks[targetTrackIndex].trackUUID;
    setState(() => _dragOffsets.remove(placement.placementUUID));
    if (tickDelta == 0 && targetTrackUUID == placement.trackUUID) return;
    final result = _actions.updatePlacement(
      placement.placementUUID,
      startTick: placement.startTick + tickDelta,
      trackUUID: targetTrackUUID,
    );
    if (mounted && result.message != null) {
      AppFeedback.info(context, result.message!);
    }
  }

  void _resizePlacementByPixels(
    TimelinePlacementData placement,
    _TimelineResizeEdge edge,
    double pixelDelta,
  ) {
    final pixelsPerTick = ref.read(timelineViewProvider).pixelsPerTick;
    final tickDelta = (pixelDelta / pixelsPerTick).round();
    setState(() => _resizePreviews.remove(placement.placementUUID));
    if (tickDelta == 0) return;
    final result = switch (edge) {
      _TimelineResizeEdge.start => _actions.resizePlacement(
        placement.placementUUID,
        startTick: math.min(
          placement.startTick + tickDelta,
          placement.endTick - 1,
        ),
      ),
      _TimelineResizeEdge.end => _actions.resizePlacement(
        placement.placementUUID,
        endTick: math.max(
          placement.endTick + tickDelta,
          placement.startTick + 1,
        ),
      ),
    };
    if (mounted && result.message != null) {
      AppFeedback.info(context, result.message!);
    }
  }

  void _updatePlacement(
    TimelinePlacementData placement, {
    int? startTick,
    int? durationTicks,
    String? trackUUID,
    String? label,
  }) {
    final result = _actions.updatePlacement(
      placement.placementUUID,
      startTick: startTick,
      durationTicks: durationTicks,
      trackUUID: trackUUID,
      label: label,
    );
    if (mounted && result.message != null) {
      AppFeedback.info(context, result.message!);
    }
  }

  Future<void> _deletePlacement(TimelinePlacementData placement) async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: "刪除時間軸節點",
      message: "將刪除此節點與其子節點；大綱場景和章節內容不會被刪除。",
      destructive: true,
    );
    if (confirmed) _actions.removePlacement(placement.placementUUID);
  }

  Future<void> _showChapterLinkDialog(TimelinePlacementData placement) async {
    final document = ref.read(timelineDocumentProvider);
    final sceneUUIDs = timelineSceneUUIDsForPlacement(
      document,
      placement.placementUUID,
    );
    if (sceneUUIDs.isEmpty) {
      AppFeedback.warning(context, "此節點沒有已連結大綱場景的子節點，無法建立章節關聯。");
      return;
    }
    final chapters = ref.read(timelineChapterIndexProvider).values.toList();
    final relevantLinks = ref
        .read(outlineChapterLinksProvider)
        .where((link) => sceneUUIDs.contains(link.sceneUUID))
        .toList(growable: false);
    final existing = relevantLinks.map((link) => link.chapterUUID).toSet();
    final coveredScenesByChapter = <String, Set<String>>{};
    for (final link in relevantLinks) {
      coveredScenesByChapter
          .putIfAbsent(link.chapterUUID, () => <String>{})
          .add(link.sceneUUID);
    }
    final selected = <String>{...existing};
    final appliesToDescendants = placement.level != TimelineElementLevel.small;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(appliesToDescendants ? "連結章節並套用到所有子節點" : "選擇關聯章節"),
          content: SizedBox(
            width: 460,
            height: math
                .min(
                  480,
                  math.max(
                    160,
                    chapters.length * 64 + (appliesToDescendants ? 72 : 0),
                  ),
                )
                .toDouble(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (appliesToDescendants) ...[
                  AppNoticeBanner(
                    message: "套用後，${sceneUUIDs.length} 個子場景會使用完全相同的章節選擇。",
                    tone: AppFeedbackTone.info,
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: chapters.isEmpty
                      ? const AppEmptyState(title: "目前沒有章節", compact: true)
                      : ListView(
                          children: [
                            for (final location in chapters)
                              CheckboxListTile(
                                value: selected.contains(
                                  location.chapter.chapterUUID,
                                ),
                                title: Text(location.chapter.chapterName),
                                subtitle: Text(
                                  appliesToDescendants &&
                                          coveredScenesByChapter.containsKey(
                                            location.chapter.chapterUUID,
                                          )
                                      ? "${location.folder.segmentName} · 目前 ${coveredScenesByChapter[location.chapter.chapterUUID]!.length}/${sceneUUIDs.length} 個子場景"
                                      : location.folder.segmentName,
                                ),
                                onChanged: (checked) {
                                  setDialogState(() {
                                    checked == true
                                        ? selected.add(
                                            location.chapter.chapterUUID,
                                          )
                                        : selected.remove(
                                            location.chapter.chapterUUID,
                                          );
                                  });
                                },
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("取消"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("套用"),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    _actions.setChapterLinksForPlacement(placement.placementUUID, selected);
    if (mounted && appliesToDescendants) {
      AppFeedback.info(context, "已將章節選擇套用到 ${sceneUUIDs.length} 個子場景。");
    }
  }
}

class _OmittedTickGap {
  final int startTick;
  final int endTick;

  const _OmittedTickGap(this.startTick, this.endTick);

  int get length => endTick - startTick;
}

/// Maps real Tick values onto the display axis without mutating timeline data.
/// Long gaps between every visible track are rendered as one display Tick.
class _TimelineTickAxis {
  static const double omittedGapDisplayTicks = 1;
  static const int minimumGapToOmit = 3;
  static const double minimumDisplayTicks = 16;

  final int minTick;
  final int maxTick;
  final List<_OmittedTickGap> omittedGaps;

  const _TimelineTickAxis._({
    required this.minTick,
    required this.maxTick,
    required this.omittedGaps,
  });

  factory _TimelineTickAxis.fromPlacements(
    List<TimelinePlacementData> placements, {
    required bool omitEmptyRanges,
    int? anchorTick,
  }) {
    if (placements.isEmpty && anchorTick == null) {
      return const _TimelineTickAxis._(
        minTick: 0,
        maxTick: 16,
        omittedGaps: <_OmittedTickGap>[],
      );
    }

    final intervals = <(int, int)>[
      for (final placement in placements)
        (placement.startTick, placement.endTick),
      if (anchorTick != null) (anchorTick, anchorTick + 1),
    ]..sort((left, right) => left.$1.compareTo(right.$1));
    var minTick = intervals.first.$1 - 2;
    var maxTick = intervals.map((interval) => interval.$2).reduce(math.max) + 3;
    final gaps = <_OmittedTickGap>[];
    if (omitEmptyRanges) {
      var occupiedEnd = intervals.first.$2;
      for (final interval in intervals.skip(1)) {
        if (interval.$1 - occupiedEnd >= minimumGapToOmit) {
          gaps.add(_OmittedTickGap(occupiedEnd, interval.$1));
        }
        occupiedEnd = math.max(occupiedEnd, interval.$2);
      }
    }

    var axis = _TimelineTickAxis._(
      minTick: minTick,
      maxTick: maxTick,
      omittedGaps: List.unmodifiable(gaps),
    );
    final missingDisplayTicks = minimumDisplayTicks - axis.displayTickSpan;
    if (missingDisplayTicks > 0) {
      maxTick += missingDisplayTicks.ceil();
      axis = _TimelineTickAxis._(
        minTick: minTick,
        maxTick: maxTick,
        omittedGaps: List.unmodifiable(gaps),
      );
    }
    return axis;
  }

  double get displayTickSpan => displayPositionForTick(maxTick);

  double displayPositionForTick(num tickValue) {
    final tick = tickValue.toDouble();
    var position = tick - minTick;
    for (final gap in omittedGaps) {
      if (tick >= gap.endTick) {
        position -= gap.length - omittedGapDisplayTicks;
        continue;
      }
      if (tick > gap.startTick) {
        final progress = (tick - gap.startTick) / gap.length;
        position -= (tick - gap.startTick) - progress * omittedGapDisplayTicks;
      }
      break;
    }
    return position;
  }

  double tickForDisplayPosition(double displayPosition) {
    if (displayPosition < 0) return minTick + displayPosition;
    var remaining = displayPosition;
    var actualTick = minTick.toDouble();
    for (final gap in omittedGaps) {
      final normalLength = gap.startTick - actualTick;
      if (remaining <= normalLength) return actualTick + remaining;
      remaining -= normalLength;
      actualTick = gap.startTick.toDouble();
      if (remaining <= omittedGapDisplayTicks) {
        return remaining < omittedGapDisplayTicks / 2
            ? actualTick
            : gap.endTick.toDouble();
      }
      remaining -= omittedGapDisplayTicks;
      actualTick = gap.endTick.toDouble();
    }
    return actualTick + remaining;
  }

  Iterable<int> get visibleTicks sync* {
    var cursor = minTick;
    for (final gap in omittedGaps) {
      for (var tick = cursor; tick <= gap.startTick; tick++) {
        yield tick;
      }
      cursor = gap.endTick;
    }
    for (var tick = cursor; tick <= maxTick; tick++) {
      yield tick;
    }
  }
}

class _TimelineScrubberHandle extends StatefulWidget {
  final _TimelineTickAxis axis;
  final int currentTick;
  final double pixelsPerTick;
  final double height;
  final ValueChanged<int> onChanged;

  const _TimelineScrubberHandle({
    required this.axis,
    required this.currentTick,
    required this.pixelsPerTick,
    required this.height,
    required this.onChanged,
  });

  @override
  State<_TimelineScrubberHandle> createState() =>
      _TimelineScrubberHandleState();
}

class _TimelineScrubberHandleState extends State<_TimelineScrubberHandle> {
  static const _stepInterval = Duration(milliseconds: 100);

  Timer? _stepTimer;
  double? _dragOriginDisplayX;
  double? _cursorDisplayX;
  double _tickRemainder = 0;
  int? _steppingTick;

  double get _displayX =>
      widget.axis.displayPositionForTick(_steppingTick ?? widget.currentTick) *
      widget.pixelsPerTick;

  void _startDrag() {
    _dragOriginDisplayX =
        widget.axis.displayPositionForTick(widget.currentTick) *
        widget.pixelsPerTick;
    _cursorDisplayX = _dragOriginDisplayX;
    _steppingTick = widget.currentTick;
    _tickRemainder = 0;
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(_stepInterval, (_) => _stepWhileDragging());
  }

  void _updateDrag(double deltaX) {
    _cursorDisplayX = (_cursorDisplayX ?? _displayX) + deltaX;
  }

  void _stepWhileDragging() {
    final dragOriginDisplayX = _dragOriginDisplayX;
    final cursorDisplayX = _cursorDisplayX;
    final currentTick = _steppingTick;
    if (!mounted ||
        dragOriginDisplayX == null ||
        cursorDisplayX == null ||
        currentTick == null) {
      return;
    }
    _tickRemainder +=
        (cursorDisplayX - dragOriginDisplayX) / widget.pixelsPerTick;
    final wholeTicks = _tickRemainder.truncate();
    if (wholeTicks == 0) return;
    _tickRemainder -= wholeTicks;
    final nextTick = currentTick + wholeTicks;
    setState(() => _steppingTick = nextTick);
    widget.onChanged(nextTick);
  }

  void _endDrag() {
    _stepTimer?.cancel();
    _stepTimer = null;
    setState(() {
      _dragOriginDisplayX = null;
      _cursorDisplayX = null;
      _tickRemainder = 0;
      _steppingTick = null;
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _displayX - 12,
      top: 0,
      width: 24,
      height: widget.height,
      child: Semantics(
        label: "時間 Scrubber，目前 ${widget.currentTick} Tick",
        slider: true,
        value: "${widget.currentTick} Tick",
        child: GestureDetector(
          key: const ValueKey("timeline-scrubber"),
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _startDrag(),
          onHorizontalDragUpdate: (details) => _updateDrag(details.delta.dx),
          onHorizontalDragEnd: (_) => _endDrag(),
          onHorizontalDragCancel: _endDrag,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Tooltip(
                message: "拖動目前時間：${widget.currentTick} Tick",
                child: Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 12,
                    color: Theme.of(context).colorScheme.onTertiary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineBoard extends StatelessWidget {
  static const double labelWidth = 112;
  static const double rulerHeight = 42;
  static const double rowHeight = 76;

  final TimelineDocumentData document;
  final List<TimelinePlacementData> placements;
  final Map<String, TimelineSceneReference> scenes;
  final String? selectedPlacementUUID;
  final double pixelsPerTick;
  final _TimelineTickAxis axis;
  final int currentTick;
  final ScrollController horizontalScrollController;
  final Map<String, Offset> dragOffsets;
  final Map<String, _TimelineResizePreview> resizePreviews;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onEnter;
  final void Function(String placementUUID, Offset delta) onDragPreview;
  final void Function(TimelinePlacementData placement, Offset delta) onMove;
  final void Function(
    String placementUUID,
    _TimelineResizeEdge edge,
    double delta,
  )
  onResizePreview;
  final void Function(
    TimelinePlacementData placement,
    _TimelineResizeEdge edge,
    double delta,
  )
  onResize;
  final ValueChanged<int> onScrub;
  final VoidCallback onAddTrack;
  final void Function(TimelineTrackData track, String action) onTrackAction;

  const _TimelineBoard({
    required this.document,
    required this.placements,
    required this.scenes,
    required this.selectedPlacementUUID,
    required this.pixelsPerTick,
    required this.axis,
    required this.currentTick,
    required this.horizontalScrollController,
    required this.dragOffsets,
    required this.resizePreviews,
    required this.onSelect,
    required this.onEnter,
    required this.onDragPreview,
    required this.onMove,
    required this.onResizePreview,
    required this.onResize,
    required this.onScrub,
    required this.onAddTrack,
    required this.onTrackAction,
  });

  @override
  Widget build(BuildContext context) {
    final tracks = [...document.tracks]
      ..sort((a, b) => a.order.compareTo(b.order));
    final width = math.max(520.0, axis.displayTickSpan * pixelsPerTick);
    final plotHeight =
        rulerHeight +
        tracks.where((track) => !track.isCollapsed).length * rowHeight;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Column(
                children: [
                  SizedBox(
                    height: rulerHeight,
                    child: Row(
                      children: [
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Text(
                              "軌道",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: "新增軌道",
                          onPressed: onAddTrack,
                          icon: const Icon(Icons.add, size: 18),
                        ),
                      ],
                    ),
                  ),
                  for (final track in tracks)
                    if (!track.isCollapsed)
                      Container(
                        height: rowHeight,
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                track.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            _trackDropdown(context, track),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Scrollbar(
                key: const ValueKey("timeline-horizontal-scrollbar"),
                controller: horizontalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SizedBox(
                      width: width,
                      height: plotHeight,
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              GestureDetector(
                                key: const ValueKey("timeline-ruler"),
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) {
                                  final tick = axis
                                      .tickForDisplayPosition(
                                        details.localPosition.dx /
                                            pixelsPerTick,
                                      )
                                      .round();
                                  onScrub(tick);
                                },
                                child: CustomPaint(
                                  size: Size(width, rulerHeight),
                                  painter: _TimelineRulerPainter(
                                    axis: axis,
                                    currentTick: currentTick,
                                    pixelsPerTick: pixelsPerTick,
                                    grid: document.grid,
                                    colorScheme: Theme.of(context).colorScheme,
                                  ),
                                ),
                              ),
                              for (final track in tracks)
                                if (!track.isCollapsed)
                                  _buildPlotRow(context, track, width),
                            ],
                          ),
                          _TimelineScrubberHandle(
                            axis: axis,
                            currentTick: currentTick,
                            pixelsPerTick: pixelsPerTick,
                            height: rulerHeight,
                            onChanged: onScrub,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        for (final track in tracks)
          if (!track.isCollapsed)
            const SizedBox.shrink()
          else
            ListTile(
              dense: true,
              leading: const Icon(Icons.chevron_right),
              title: Text(track.name),
              trailing: _trackDropdown(context, track),
            ),
      ],
    );
  }

  Widget _trackDropdown(BuildContext context, TimelineTrackData track) {
    final error = Theme.of(context).colorScheme.error;
    return PopupMenuButton<String>(
      tooltip: "軌道選項",
      icon: const Icon(Icons.arrow_drop_down, size: 22),
      onSelected: (action) => onTrackAction(track, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: "rename",
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text("重新命名"),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: "toggle",
          child: ListTile(
            leading: Icon(
              track.isCollapsed ? Icons.unfold_more : Icons.unfold_less,
            ),
            title: Text(track.isCollapsed ? "展開軌道" : "收合軌道"),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: "up",
          child: ListTile(
            leading: Icon(Icons.arrow_upward),
            title: Text("上移"),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: "down",
          child: ListTile(
            leading: Icon(Icons.arrow_downward),
            title: Text("下移"),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: "delete",
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: error),
            title: Text("刪除軌道", style: TextStyle(color: error)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildPlotRow(
    BuildContext context,
    TimelineTrackData track,
    double width,
  ) {
    final lane = placements
        .where((placement) => placement.trackUUID == track.trackUUID)
        .toList(growable: false);
    return SizedBox(
      height: rowHeight,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(width, rowHeight),
            painter: _TimelineGridPainter(
              axis: axis,
              currentTick: currentTick,
              pixelsPerTick: pixelsPerTick,
              colorScheme: Theme.of(context).colorScheme,
              ticksPerMiddle:
                  document.grid.ticksPerSmallBox *
                  document.grid.ticksPerMiddleBox,
            ),
          ),
          for (final placement in lane) _placementCard(context, placement),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 1,
            child: ColoredBox(color: Theme.of(context).dividerColor),
          ),
        ],
      ),
    );
  }

  Widget _placementCard(BuildContext context, TimelinePlacementData placement) {
    final selected = placement.placementUUID == selectedPlacementUUID;
    final scheme = Theme.of(context).colorScheme;
    final rawDragOffset = dragOffsets[placement.placementUUID] ?? Offset.zero;
    final visibleTracks =
        ([...document.tracks]..sort((a, b) => a.order.compareTo(b.order)))
            .where((track) => !track.isCollapsed)
            .toList(growable: false);
    final currentTrackIndex = visibleTracks.indexWhere(
      (track) => track.trackUUID == placement.trackUUID,
    );
    final minimumVerticalOffset = currentTrackIndex < 0
        ? 0.0
        : -currentTrackIndex * rowHeight;
    final maximumVerticalOffset = currentTrackIndex < 0
        ? 0.0
        : (visibleTracks.length - currentTrackIndex - 1) * rowHeight;
    final dragOffset = Offset(
      rawDragOffset.dx,
      rawDragOffset.dy.clamp(minimumVerticalOffset, maximumVerticalOffset),
    );
    final resizePreview = resizePreviews[placement.placementUUID];
    final maximumShrink = (placement.durationTicks - 1) * pixelsPerTick;
    final resizeDelta = switch (resizePreview?.edge) {
      _TimelineResizeEdge.start => math.min(
        resizePreview!.pixelDelta,
        maximumShrink,
      ),
      _TimelineResizeEdge.end => math.max(
        resizePreview!.pixelDelta,
        -maximumShrink,
      ),
      null => 0.0,
    };
    final startResizeDelta = resizePreview?.edge == _TimelineResizeEdge.start
        ? resizeDelta
        : 0.0;
    final endResizeDelta = resizePreview?.edge == _TimelineResizeEdge.end
        ? resizeDelta
        : 0.0;
    final placementDisplayTicks =
        axis.displayPositionForTick(placement.endTick) -
        axis.displayPositionForTick(placement.startTick);
    final width = math.max(
      44.0,
      placementDisplayTicks * pixelsPerTick -
          4 -
          startResizeDelta +
          endResizeDelta,
    );
    var moveAccumulated = dragOffset;
    var verticalHandleAccumulated = dragOffset.dy;
    var startAccumulated = startResizeDelta;
    var endAccumulated = endResizeDelta;

    double actualPixelDelta(int tick, double displayPixelDelta) {
      final displayPosition =
          axis.displayPositionForTick(tick) + displayPixelDelta / pixelsPerTick;
      final targetTick = axis.tickForDisplayPosition(displayPosition).round();
      return (targetTick - tick) * pixelsPerTick;
    }

    Widget resizeHandle(_TimelineResizeEdge edge) {
      final isStart = edge == _TimelineResizeEdge.start;
      return Tooltip(
        message: isStart ? "拖曳調整頭端 Tick" : "拖曳調整尾端 Tick",
        child: Semantics(
          label: isStart ? "調整頭端 Tick" : "調整尾端 Tick",
          child: GestureDetector(
            key: ValueKey(
              "timeline-resize-${isStart ? 'start' : 'end'}-${placement.placementUUID}",
            ),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              onSelect(placement.placementUUID);
              if (isStart) {
                startAccumulated = 0;
              } else {
                endAccumulated = 0;
              }
              onResizePreview(placement.placementUUID, edge, 0);
            },
            onHorizontalDragUpdate: (details) {
              if (isStart) {
                startAccumulated += details.delta.dx;
                onResizePreview(
                  placement.placementUUID,
                  edge,
                  startAccumulated,
                );
              } else {
                endAccumulated += details.delta.dx;
                onResizePreview(placement.placementUUID, edge, endAccumulated);
              }
            },
            onHorizontalDragEnd: (_) {
              final boundaryTick = isStart
                  ? placement.startTick
                  : placement.endTick;
              final displayDelta = isStart ? startAccumulated : endAccumulated;
              onResize(
                placement,
                edge,
                actualPixelDelta(boundaryTick, displayDelta),
              );
            },
            onHorizontalDragCancel: () => onResize(placement, edge, 0),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: SizedBox(
                width: 14,
                child: Center(
                  child: Container(
                    width: 3,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? scheme.primary : scheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left:
          axis.displayPositionForTick(placement.startTick) * pixelsPerTick +
          2 +
          dragOffset.dx +
          startResizeDelta,
      top: 10 + dragOffset.dy,
      width: width,
      height: rowHeight - 20,
      child: Semantics(
        button: true,
        selected: selected,
        label: _placementLabel(placement, scenes),
        child: AnimatedContainer(
          duration: dragOffset == Offset.zero && resizePreview == null
              ? const Duration(milliseconds: 120)
              : Duration.zero,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.18),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              resizeHandle(_TimelineResizeEdge.start),
              Expanded(
                child: GestureDetector(
                  key: ValueKey("timeline-move-${placement.placementUUID}"),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(placement.placementUUID),
                  onDoubleTap: () => onEnter(placement.placementUUID),
                  onHorizontalDragStart: (_) {
                    moveAccumulated = Offset.zero;
                    onDragPreview(placement.placementUUID, Offset.zero);
                  },
                  onHorizontalDragUpdate: (details) {
                    moveAccumulated += Offset(details.delta.dx, 0);
                    onDragPreview(placement.placementUUID, moveAccumulated);
                  },
                  onHorizontalDragEnd: (_) => onMove(
                    placement,
                    Offset(
                      actualPixelDelta(placement.startTick, moveAccumulated.dx),
                      moveAccumulated.dy,
                    ),
                  ),
                  onHorizontalDragCancel: () => onMove(placement, Offset.zero),
                  onVerticalDragStart: (_) {
                    moveAccumulated = Offset.zero;
                    onDragPreview(placement.placementUUID, Offset.zero);
                  },
                  onVerticalDragUpdate: (details) {
                    moveAccumulated += Offset(0, details.delta.dy);
                    onDragPreview(placement.placementUUID, moveAccumulated);
                  },
                  onVerticalDragEnd: (_) => onMove(placement, moveAccumulated),
                  onVerticalDragCancel: () => onMove(placement, Offset.zero),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.move,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: "拖曳以調整時間",
                              child: Draggable<String>(
                                key: ValueKey(
                                  "timeline-move-vertical-${placement.placementUUID}",
                                ),
                                data: placement.placementUUID,
                                axis: Axis.vertical,
                                affinity: Axis.vertical,
                                rootOverlay: true,
                                feedback: const SizedBox.shrink(),
                                onDragStarted: () {
                                  verticalHandleAccumulated = 0;
                                  onSelect(placement.placementUUID);
                                  onDragPreview(
                                    placement.placementUUID,
                                    Offset.zero,
                                  );
                                },
                                onDragUpdate: (details) {
                                  verticalHandleAccumulated += details.delta.dy;
                                  onDragPreview(
                                    placement.placementUUID,
                                    Offset(0, verticalHandleAccumulated),
                                  );
                                },
                                onDragEnd: (_) => onMove(
                                  placement,
                                  Offset(0, verticalHandleAccumulated),
                                ),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeUpDown,
                                  child: Text(
                                    _placementLabel(placement, scenes),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              resizeHandle(_TimelineResizeEdge.end),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineInspector extends StatefulWidget {
  final TimelinePlacementData? placement;
  final TimelineDocumentData document;
  final Map<String, TimelineSceneReference> scenes;
  final Map<String, ChapterLocation> chapters;
  final List<OutlineChapterLinkData> links;
  final void Function(
    TimelinePlacementData placement, {
    int? startTick,
    int? durationTicks,
    String? trackUUID,
    String? label,
  })
  onUpdate;
  final ValueChanged<TimelinePlacementData> onDelete;
  final ValueChanged<TimelinePlacementData> onAddChapterLink;
  final void Function(TimelinePlacementData placement, String chapterUUID)
  onRemoveChapterLink;
  final TimelineOpenChapter? onOpenChapter;
  final TimelineOpenOutlineScene? onOpenOutlineScene;

  const _TimelineInspector({
    required this.placement,
    required this.document,
    required this.scenes,
    required this.chapters,
    required this.links,
    required this.onUpdate,
    required this.onDelete,
    required this.onAddChapterLink,
    required this.onRemoveChapterLink,
    required this.onOpenChapter,
    required this.onOpenOutlineScene,
  });

  @override
  State<_TimelineInspector> createState() => _TimelineInspectorState();
}

class _TimelineInspectorState extends State<_TimelineInspector> {
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.placement?.label ?? "",
    );
  }

  @override
  void didUpdateWidget(covariant _TimelineInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement?.placementUUID != widget.placement?.placementUUID ||
        oldWidget.placement?.label != widget.placement?.label) {
      _labelController.text = widget.placement?.label ?? "";
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placement = widget.placement;
    if (placement == null) {
      return const AppSectionCard(
        title: "節點屬性",
        icon: Icons.tune,
        child: AppEmptyState(
          title: "尚未選取節點",
          description: "點一下時間軸節點即可檢視與調整 Tick、軌道及章節關聯。",
          icon: Icons.touch_app_outlined,
          compact: true,
        ),
      );
    }
    final scene = placement.sceneUUID == null
        ? null
        : widget.scenes[placement.sceneUUID];
    final sceneUUIDs = timelineSceneUUIDsForPlacement(
      widget.document,
      placement.placementUUID,
    );
    final links =
        widget.links
            .where((link) => sceneUUIDs.contains(link.sceneUUID))
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final chapterUUIDs = <String>[];
    final linkedScenesByChapter = <String, Set<String>>{};
    for (final link in links) {
      if (!chapterUUIDs.contains(link.chapterUUID)) {
        chapterUUIDs.add(link.chapterUUID);
      }
      linkedScenesByChapter
          .putIfAbsent(link.chapterUUID, () => <String>{})
          .add(link.sceneUUID);
    }
    final isContainer = placement.level != TimelineElementLevel.small;
    final tracks = [...widget.document.tracks]
      ..sort((a, b) => a.order.compareTo(b.order));
    return AppSectionCard(
      title: "節點屬性",
      icon: Icons.tune,
      actions: [
        IconButton(
          tooltip: "刪除節點",
          onPressed: () => widget.onDelete(placement),
          icon: const Icon(Icons.delete_outline),
          style: IconButton.styleFrom(foregroundColor: Colors.red),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "${_levelLabel(placement.level)} · ${_placementLabel(placement, widget.scenes)}",
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          AppTextField(
            key: ValueKey("timeline-label-${placement.placementUUID}"),
            controller: _labelController,
            labelText: "自訂名稱",
            hintText: scene?.scene.sceneName ?? "節點名稱",
            textInputAction: TextInputAction.done,
            onSubmitted: (value) =>
                widget.onUpdate(placement, label: value.trim()),
            onTapOutside: (_) {
              final value = _labelController.text.trim();
              if (value != placement.label) {
                widget.onUpdate(placement, label: value);
              }
            },
          ),
          const SizedBox(height: 12),
          AppDropdownField<String>(
            value: placement.trackUUID,
            labelText: "所在軌道",
            options: [
              for (final track in tracks)
                DropdownOption(value: track.trackUUID, label: track.name),
            ],
            onChanged: (trackUUID) {
              if (trackUUID != null) {
                widget.onUpdate(placement, trackUUID: trackUUID);
              }
            },
          ),
          const SizedBox(height: 8),
          _NumberStepper(
            label: "頭端 Tick",
            value: placement.startTick,
            minimum: -0x7fffffff,
            allowNegative: true,
            onChanged: (value) => widget.onUpdate(placement, startTick: value),
          ),
          _NumberStepper(
            label: "Tick 數",
            value: placement.durationTicks,
            onChanged: (value) =>
                widget.onUpdate(placement, durationTicks: value),
          ),
          _NumberStepper(
            label: "尾端 Tick",
            value: placement.endTick,
            minimum: placement.startTick + 1,
            allowNegative: true,
            onChanged: (value) => widget.onUpdate(
              placement,
              durationTicks: value - placement.startTick,
            ),
          ),
          if (sceneUUIDs.isNotEmpty) ...[
            const Divider(height: 28),
            if (scene != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_tree_outlined),
                title: Text(
                  scene.scene.sceneName.isEmpty
                      ? "未命名場景"
                      : scene.scene.sceneName,
                ),
                subtitle: Text(
                  "${scene.storyline.storylineName} · ${scene.event.storyEvent}",
                ),
                trailing: widget.onOpenOutlineScene == null
                    ? null
                    : IconButton(
                        tooltip: "在大綱中開啟",
                        onPressed: () =>
                            widget.onOpenOutlineScene!(scene.scene.sceneUUID),
                        icon: const Icon(Icons.open_in_new),
                      ),
              )
            else
              AppNoticeBanner(
                message: "以下章節彙整自 ${sceneUUIDs.length} 個子場景。",
                tone: AppFeedbackTone.info,
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "關聯章節",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: isContainer ? "連結章節並套用到所有子節點" : "選擇章節",
                  onPressed: () => widget.onAddChapterLink(placement),
                  icon: Icon(isContainer ? Icons.account_tree : Icons.add_link),
                ),
              ],
            ),
            if (links.isEmpty)
              AppEmptyState(
                title: isContainer ? "子場景尚未連結章節" : "此場景尚未連結章節",
                description: isContainer ? "可選擇章節並一次套用到所有子節點。" : "不會自動切換到第一章。",
                icon: Icons.link_off,
                compact: true,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chapterUUID in chapterUUIDs)
                    InputChip(
                      avatar: const Icon(Icons.menu_book, size: 16),
                      label: Text(
                        "${widget.chapters[chapterUUID]?.chapter.chapterName ?? "缺失章節"}${isContainer ? " (${linkedScenesByChapter[chapterUUID]?.length ?? 0}/${sceneUUIDs.length})" : ""}",
                      ),
                      onPressed:
                          widget.onOpenChapter == null ||
                              !widget.chapters.containsKey(chapterUUID)
                          ? null
                          : () => widget.onOpenChapter!(chapterUUID),
                      onDeleted: () =>
                          widget.onRemoveChapterLink(placement, chapterUUID),
                    ),
                ],
              ),
          ] else ...[
            const Divider(height: 28),
            AppNoticeBanner(
              message: isContainer
                  ? "此容器目前沒有可連結章節的子場景；請先新增小箱。"
                  : "此小箱尚未連結大綱場景，無法建立章節關聯。",
              tone: AppFeedbackTone.info,
            ),
          ],
        ],
      ),
    );
  }
}

class _NumberStepper extends StatefulWidget {
  final String label;
  final int value;
  final int minimum;
  final bool allowNegative;
  final ValueChanged<int> onChanged;

  const _NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.minimum = 1,
    this.allowNegative = false,
  });

  @override
  State<_NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<_NumberStepper> {
  late final TextEditingController _valueController;
  late final FocusNode _valueFocusNode;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: "${widget.value}");
    _valueFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _NumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_valueFocusNode.hasFocus) {
      _valueController.text = "${widget.value}";
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _valueFocusNode.dispose();
    super.dispose();
  }

  int get _minimum => widget.allowNegative
      ? widget.minimum
      : math.max(1, widget.minimum).toInt();

  void _commitValue() {
    final parsedValue = int.tryParse(_valueController.text.trim());
    if (parsedValue == null) {
      _valueController.text = "${widget.value}";
      return;
    }

    final nextValue = math.max(_minimum, parsedValue).toInt();
    _valueController.text = "$nextValue";
    if (nextValue != widget.value) {
      widget.onChanged(nextValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(widget.label)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: "減少",
              onPressed: widget.value > _minimum
                  ? () => widget.onChanged(widget.value - 1)
                  : null,
              icon: const Icon(Icons.remove_circle),
              style: IconButton.styleFrom(foregroundColor: Colors.red),
            ),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _valueController,
                focusNode: _valueFocusNode,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(
                  signed: widget.allowNegative,
                ),
                style: Theme.of(context).textTheme.titleSmall,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                ),
                onTap: () => _valueController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _valueController.text.length,
                ),
                onSubmitted: (_) {
                  _commitValue();
                  _valueFocusNode.unfocus();
                },
                onTapOutside: (_) {
                  _commitValue();
                  _valueFocusNode.unfocus();
                },
              ),
            ),
            IconButton(
              tooltip: "增加",
              onPressed: () => widget.onChanged(widget.value + 1),
              icon: const Icon(Icons.add_circle),
              style: IconButton.styleFrom(foregroundColor: Colors.green),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelineRulerPainter extends CustomPainter {
  final _TimelineTickAxis axis;
  final int currentTick;
  final double pixelsPerTick;
  final TimelineGridConfig grid;
  final ColorScheme colorScheme;

  const _TimelineRulerPainter({
    required this.axis,
    required this.currentTick,
    required this.pixelsPerTick,
    required this.grid,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colorScheme.surfaceContainerHigh,
    );
    final minorPaint = Paint()..color = colorScheme.outlineVariant;
    final majorPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    for (final gap in axis.omittedGaps) {
      final startX = axis.displayPositionForTick(gap.startTick) * pixelsPerTick;
      final endX = axis.displayPositionForTick(gap.endTick) * pixelsPerTick;
      canvas.drawRect(
        Rect.fromLTRB(startX, 0, endX, size.height),
        Paint()..color = colorScheme.surfaceContainerHighest,
      );
      final centerX = (startX + endX) / 2;
      final breakPaint = Paint()
        ..color = colorScheme.primary
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(centerX - 7, size.height * 0.34),
        Offset(centerX - 1, size.height * 0.66),
        breakPaint,
      );
      canvas.drawLine(
        Offset(centerX + 1, size.height * 0.34),
        Offset(centerX + 7, size.height * 0.66),
        breakPaint,
      );
    }
    for (final tick in axis.visibleTicks) {
      final x = axis.displayPositionForTick(tick) * pixelsPerTick;
      if (x < 0 || x > size.width) continue;
      final major =
          tick % (grid.ticksPerSmallBox * grid.ticksPerMiddleBox) == 0;
      canvas.drawLine(
        Offset(x, major ? 0 : size.height * 0.45),
        Offset(x, size.height),
        major ? majorPaint : minorPaint,
      );
      if (pixelsPerTick >= 28 || major) {
        final painter = TextPainter(
          text: TextSpan(
            text: "$tick",
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: major ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(x + 4, 7));
      }
    }
    final playheadX = axis.displayPositionForTick(currentTick) * pixelsPerTick;
    final playheadPaint = Paint()
      ..color = colorScheme.tertiary
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      playheadPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(playheadX - 6, 0)
        ..lineTo(playheadX + 6, 0)
        ..lineTo(playheadX, 8)
        ..close(),
      playheadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.axis != axis ||
        oldDelegate.currentTick != currentTick ||
        oldDelegate.pixelsPerTick != pixelsPerTick ||
        oldDelegate.grid != grid ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _TimelineGridPainter extends CustomPainter {
  final _TimelineTickAxis axis;
  final int currentTick;
  final double pixelsPerTick;
  final ColorScheme colorScheme;
  final int ticksPerMiddle;

  const _TimelineGridPainter({
    required this.axis,
    required this.currentTick,
    required this.pixelsPerTick,
    required this.colorScheme,
    required this.ticksPerMiddle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colorScheme.surfaceContainerLowest,
    );
    for (final gap in axis.omittedGaps) {
      final startX = axis.displayPositionForTick(gap.startTick) * pixelsPerTick;
      final endX = axis.displayPositionForTick(gap.endTick) * pixelsPerTick;
      canvas.drawRect(
        Rect.fromLTRB(startX, 0, endX, size.height),
        Paint()
          ..color = colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
      );
    }
    for (final tick in axis.visibleTicks) {
      final x = axis.displayPositionForTick(tick) * pixelsPerTick;
      if (x < 0 || x > size.width) continue;
      final major = tick % ticksPerMiddle == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = major
              ? colorScheme.primary.withValues(alpha: 0.16)
              : colorScheme.outlineVariant.withValues(alpha: 0.45)
          ..strokeWidth = major ? 1.4 : 1,
      );
    }
    final playheadX = axis.displayPositionForTick(currentTick) * pixelsPerTick;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, size.height),
      Paint()
        ..color = colorScheme.tertiary.withValues(alpha: 0.78)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()..color = colorScheme.outlineVariant,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelineGridPainter oldDelegate) {
    return oldDelegate.axis != axis ||
        oldDelegate.currentTick != currentTick ||
        oldDelegate.pixelsPerTick != pixelsPerTick ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.ticksPerMiddle != ticksPerMiddle;
  }
}

String _placementLabel(
  TimelinePlacementData placement,
  Map<String, TimelineSceneReference> scenes,
) {
  if (placement.label.trim().isNotEmpty) return placement.label.trim();
  final scene = placement.sceneUUID == null
      ? null
      : scenes[placement.sceneUUID];
  if (scene?.scene.sceneName.trim().isNotEmpty == true) {
    return scene!.scene.sceneName.trim();
  }
  return "未命名${_levelLabel(placement.level)}";
}

String _levelLabel(TimelineElementLevel level) => switch (level) {
  TimelineElementLevel.large => "大箱",
  TimelineElementLevel.middle => "中箱",
  TimelineElementLevel.small => "小箱",
};

String _unitLabel(TickDurationUnit unit) => switch (unit) {
  TickDurationUnit.second => "秒",
  TickDurationUnit.minute => "分鐘",
  TickDurationUnit.hour => "小時",
  TickDurationUnit.day => "天",
  TickDurationUnit.week => "週",
  TickDurationUnit.month => "月",
  TickDurationUnit.season => "季節",
  TickDurationUnit.year => "年",
  TickDurationUnit.decade => "十年",
  TickDurationUnit.century => "世紀",
  TickDurationUnit.custom => "自訂單位",
};
