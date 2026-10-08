import "dart:math" as math;

import "package:flutter/foundation.dart" show listEquals;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../models/timeline_data.dart";
import "../../ui_library/mini_timeline.dart";
import "../../bin/ui_library.dart" show DropdownOption;
import "../../ui_library/menu_button.dart";
import "../../ui_library/neon_icon_button.dart";
import "../../ui_library/neon_ui_theme.dart";
import "../../ui_library/spacing.dart";
import "../providers/project_state_providers.dart";
import "../providers/snapshot_timeline_providers.dart";
import "../providers/timeline_providers.dart";
import "timeline_mini_view.dart";

/// Pages may opt into exact-Tick event selection to load their snapshot editor.
/// The page controls [mode]; local previews also control [localTick].
class SnapshotTimelinePreview extends ConsumerStatefulWidget {
  final SnapshotTimelineSubject subject;
  final SnapshotPreviewMode mode;
  final int? localTick;
  final ValueChanged<SnapshotPreviewMode>? onModeChanged;
  final ValueChanged<int>? onTickChanged;
  final ValueChanged<SnapshotTimelineEvent?>? onEventSelected;
  final ValueChanged<SnapshotTimelineEvent>? onCopy;
  final ValueChanged<SnapshotTimelineEvent>? onDelete;

  /// Leading snapshot actions receive the explicitly selected event, if any.
  final List<Widget> Function(SnapshotTimelineEvent?)? snapshotActionsBuilder;
  final bool allowLocalMode;
  final bool autoSelectAtTick;
  final String? selectedEventId;
  final bool allowBaseline;
  final bool allowLocateMainTimeline;
  final List<TimelinePlacementData>? placementsOverride;
  final int? minTick;
  final int? maxTick;
  final Key? canvasKey;
  final String? emptyMessage;
  final String? hint;

  const SnapshotTimelinePreview({
    super.key,
    required this.subject,
    this.mode = SnapshotPreviewMode.followTimeline,
    this.localTick,
    this.onModeChanged,
    this.onTickChanged,
    this.onEventSelected,
    this.onCopy,
    this.onDelete,
    this.snapshotActionsBuilder,
    this.allowLocalMode = false,
    this.autoSelectAtTick = false,
    this.selectedEventId,
    this.allowBaseline = true,
    this.allowLocateMainTimeline = true,
    this.placementsOverride,
    this.minTick,
    this.maxTick,
    this.canvasKey,
    this.emptyMessage,
    this.hint,
  });

  @override
  ConsumerState<SnapshotTimelinePreview> createState() =>
      _SnapshotTimelinePreviewState();
}

class _SnapshotTimelinePreviewState
    extends ConsumerState<SnapshotTimelinePreview> {
  final _tickController = TextEditingController();
  final _tickFocus = FocusNode();
  final _toolbarController = ScrollController();
  String? _selectedId;
  ({
    SnapshotTimelineSubject subject,
    SnapshotPreviewMode mode,
    int tick,
    String? id,
  })?
  _notifiedSelection;
  bool _completeContext = false;
  bool _toolbarHovered = false;
  double _scale = 48;
  List<SnapshotTimelineEvent>? _rangeEvents;
  List<TimelinePlacementData>? _rangePlacements;
  int _min = 0;
  int _max = 10;
  bool get _canNavigate => switch (widget.mode) {
    SnapshotPreviewMode.baseline => widget.onModeChanged != null,
    SnapshotPreviewMode.localTick => widget.onTickChanged != null,
    SnapshotPreviewMode.followTimeline => true,
  };
  int get _tick => widget.mode == SnapshotPreviewMode.localTick
      ? widget.localTick ?? 0
      : ref.read(timelineViewProvider).currentTick;

  @override
  void didUpdateWidget(covariant SnapshotTimelinePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subject != widget.subject) {
      _selectedId = null;
      _notifiedSelection = null;
      _rangeEvents = null;
      _completeContext = false;
    }
  }

  @override
  void dispose() {
    _tickController.dispose();
    _tickFocus.dispose();
    _toolbarController.dispose();
    super.dispose();
  }

  void _setMode(SnapshotPreviewMode mode) {
    if (mode == SnapshotPreviewMode.localTick) {
      widget.onTickChanged?.call(_tick);
    }
    setState(() => _selectedId = null);
    if (!widget.autoSelectAtTick) widget.onEventSelected?.call(null);
    widget.onModeChanged?.call(mode);
  }

  void _pickTick(int value) {
    final tick = clampTimelineTick(value);
    var mode = widget.mode;
    if (mode == SnapshotPreviewMode.baseline) {
      mode = widget.allowLocalMode
          ? SnapshotPreviewMode.localTick
          : SnapshotPreviewMode.followTimeline;
      widget.onModeChanged?.call(mode);
    }
    if (mode == SnapshotPreviewMode.localTick) {
      widget.onTickChanged?.call(tick);
    } else {
      ref.read(timelineViewProvider.notifier).setCurrentTick(tick);
    }
    final events = ref.read(snapshotTimelineEventsProvider(widget.subject));
    final selected = events.where((e) => e.id == _selectedId).firstOrNull;
    if (selected == null || selected.tick != tick) {
      setState(() => _selectedId = null);
      if (!widget.autoSelectAtTick) widget.onEventSelected?.call(null);
    }
  }

  Future<void> _pickEvents(List<SnapshotTimelineEvent> events) async {
    SnapshotTimelineEvent? selected;
    if (events.length == 1) {
      selected = events.single;
    } else {
      selected = await showDialog<SnapshotTimelineEvent>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Tick ${events.first.tick} 的事件"),
          content: SizedBox(
            width: 440,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final event in events)
                  ListTile(
                    key: ValueKey("snapshot-event-${event.id}"),
                    title: Text(event.label),
                    subtitle: Text(event.description),
                    leading: Icon(
                      event.inherited
                          ? Icons.account_tree_outlined
                          : Icons.movie_outlined,
                    ),
                    onTap: () => Navigator.pop(context, event),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消"),
            ),
          ],
        ),
      );
    }
    if (!mounted || selected == null) return;
    // The event may have been deleted while the chooser was open.
    if (!ref
        .read(snapshotTimelineEventsProvider(widget.subject))
        .any((e) => e.id == selected!.id)) {
      return;
    }
    _pickTick(selected.tick);
    setState(() => _selectedId = selected!.id);
    widget.onEventSelected?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(snapshotTimelineEventsProvider(widget.subject));
    final document = ref.watch(timelineDocumentProvider);
    final globalTick = ref.watch(
      timelineViewProvider.select((state) => state.currentTick),
    );
    final tick = widget.mode == SnapshotPreviewMode.localTick
        ? widget.localTick ?? 0
        : globalTick;
    var selected = events.where((e) => e.id == _selectedId).firstOrNull;
    if (widget.autoSelectAtTick) {
      selected = widget.mode == SnapshotPreviewMode.followTimeline
          ? snapshotEventAtTick(
              events,
              tick,
              selectedId: widget.selectedEventId ?? _selectedId,
            )
          : null;
      _selectedId = selected?.id;
      final selection = (
        subject: widget.subject,
        mode: widget.mode,
        tick: tick,
        id: _selectedId,
      );
      if (_notifiedSelection != selection) {
        _notifiedSelection = selection;
        final event = selected;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _notifiedSelection == selection) {
            widget.onEventSelected?.call(event);
          }
        });
      }
    }
    if (_selectedId != null && (selected == null || selected.tick != tick)) {
      _selectedId = null;
      selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onEventSelected?.call(null);
      });
    }
    final allPlacements =
        widget.placementsOverride ??
        document.placements
            .where(
              (p) =>
                  p.sceneUUID != null && p.level == TimelineElementLevel.small,
            )
            .toList();
    final placementIds = events.map((e) => e.placementUUID).toSet();
    final placements = _completeContext || widget.placementsOverride != null
        ? allPlacements
        : allPlacements
              .where((p) => placementIds.contains(p.placementUUID))
              .toList();
    if (!identical(events, _rangeEvents) ||
        !listEquals(placements, _rangePlacements)) {
      _rangeEvents = events;
      _rangePlacements = placements;
      final values = [
        tick,
        ...events.map((e) => e.tick),
        for (final p in placements) ...[p.startTick, p.endTick],
      ];
      _min = clampTimelineTick(values.reduce(math.min) - 2);
      _max = clampTimelineTick(values.reduce(math.max) + 2);
    }
    // Keep the range stable while dragging; expand for an external cursor move.
    _min = math.min(_min, tick);
    _max = math.max(_max, tick);
    if (!_tickFocus.hasFocus && _tickController.text != "$tick") {
      _tickController.text = "$tick";
    }
    final previous = events.where((e) => e.tick < tick).lastOrNull;
    final next = events.where((e) => e.tick > tick).firstOrNull;
    final hint =
        widget.hint ??
        (widget.autoSelectAtTick
            ? widget.mode == SnapshotPreviewMode.baseline
                  ? "目前編輯預設資料；開啟「跟隨時間軸」可預覽指定 Tick。"
                  : selected == null
                  ? "此 Tick 無快照，僅供預覽；新增快照後即可編輯。"
                  : selected.inherited
                  ? "此 Tick 僅有 Class 繼承狀態，僅供預覽；新增單件快照後即可編輯。"
                  : "目前編輯此 Tick 的快照，變更只會儲存至此事件。"
            : null);
    final actions =
        widget.snapshotActionsBuilder?.call(selected) ??
        [
          if (widget.onCopy != null)
            NeonIconButton(
              label: "複製快照",
              icon: Icons.copy_outlined,
              onPressed: selected == null || selected.inherited
                  ? null
                  : () => widget.onCopy!(selected!),
            ),
          if (widget.onDelete != null)
            NeonIconButton(
              label: "刪除快照",
              icon: Icons.delete_outline,
              destructive: true,
              onPressed: selected == null || selected.inherited
                  ? null
                  : () => widget.onDelete!(selected!),
            ),
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          key: const ValueKey("snapshot-preview-toolbar-hover"),
          onEnter: (_) => setState(() => _toolbarHovered = true),
          onExit: (_) => setState(() => _toolbarHovered = false),
          child: Scrollbar(
            key: const ValueKey("snapshot-preview-toolbar-scrollbar"),
            controller: _toolbarController,
            thumbVisibility: _toolbarHovered,
            thickness: _toolbarHovered ? null : 0,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            notificationPredicate: (notification) => notification.depth == 0,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                key: const ValueKey("snapshot-preview-toolbar-scroll-area"),
                controller: _toolbarController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(
                  top:
                      AppSpacing.sm + MediaQuery.textScalerOf(context).scale(4),
                  bottom: AppSpacing.md,
                ),
                child: Row(
                  spacing: 6,
                  children: [
                    if (hint != null)
                      Tooltip(
                        key: const ValueKey("snapshot-preview-hint"),
                        message: hint,
                        waitDuration: const Duration(milliseconds: 350),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (actions.isNotEmpty) ...[
                      ...actions,
                      const SizedBox(
                        height: 32,
                        child: VerticalDivider(width: 16),
                      ),
                    ],
                    if (widget.allowBaseline || widget.allowLocalMode)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.allowLocalMode)
                            NeonIconButton(
                              key: const ValueKey("snapshot-preview-local"),
                              label: "獨立預覽",
                              icon: Icons.history_toggle_off_outlined,
                              selected:
                                  widget.mode == SnapshotPreviewMode.localTick,
                              status:
                                  widget.mode == SnapshotPreviewMode.localTick
                                  ? NeonStatus.preview
                                  : NeonStatus.idle,
                              statusLabel:
                                  widget.mode == SnapshotPreviewMode.localTick
                                  ? "歷史預覽"
                                  : null,
                              onPressed:
                                  widget.onModeChanged == null ||
                                      widget.onTickChanged == null
                                  ? null
                                  : () => _setMode(
                                      widget.mode ==
                                              SnapshotPreviewMode.localTick
                                          ? SnapshotPreviewMode.baseline
                                          : SnapshotPreviewMode.localTick,
                                    ),
                            ),
                          if (widget.allowLocalMode || widget.allowBaseline)
                            NeonIconButton(
                              key: const ValueKey("snapshot-preview-follow"),
                              label: "跟隨時間軸",
                              icon: Icons.playlist_add_check_rounded,
                              selected:
                                  widget.mode ==
                                  SnapshotPreviewMode.followTimeline,
                              onPressed: widget.onModeChanged == null
                                  ? null
                                  : () => _setMode(
                                      widget.mode ==
                                              SnapshotPreviewMode.followTimeline
                                          ? widget.allowBaseline
                                                ? SnapshotPreviewMode.baseline
                                                : SnapshotPreviewMode.localTick
                                          : SnapshotPreviewMode.followTimeline,
                                    ),
                            ),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NeonIconButton(
                          label: "上一事件",
                          onPressed: previous == null || !_canNavigate
                              ? null
                              : () => _pickEvents(
                                  events
                                      .where((e) => e.tick == previous.tick)
                                      .toList(),
                                ),
                          icon: Icons.skip_previous,
                        ),
                        SizedBox(
                          width: 116,
                          child: TextField(
                            enabled: _canNavigate,
                            key: const ValueKey("snapshot-preview-tick"),
                            controller: _tickController,
                            focusNode: _tickFocus,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: "Tick",
                              isDense: true,
                            ),
                            onSubmitted: (text) {
                              final value = int.tryParse(text.trim());
                              if (value != null) _pickTick(value);
                              _tickFocus.unfocus();
                              _tickController.text =
                                  "${value == null ? tick : clampTimelineTick(value)}";
                            },
                          ),
                        ),
                        NeonIconButton(
                          label: "下一事件",
                          onPressed: next == null || !_canNavigate
                              ? null
                              : () => _pickEvents(
                                  events
                                      .where((e) => e.tick == next.tick)
                                      .toList(),
                                ),
                          icon: Icons.skip_next,
                        ),
                      ],
                    ),
                    if (widget.allowLocateMainTimeline)
                      NeonIconButton(
                        label: "定位主時間軸",
                        onPressed: widget.mode == SnapshotPreviewMode.baseline
                            ? null
                            : () {
                                final notifier = ref.read(
                                  timelineViewProvider.notifier,
                                );
                                notifier.setCurrentTick(tick);
                                if (selected?.placementUUID != null) {
                                  notifier.select(selected!.placementUUID);
                                }
                              },
                        icon: Icons.my_location_outlined,
                      ),
                    NeonIconButton(
                      label: "縮小",
                      onPressed: _scale <= 12
                          ? null
                          : () => setState(() => _scale /= 2),
                      icon: Icons.zoom_out,
                    ),
                    NeonIconButton(
                      label: "放大",
                      onPressed: _scale >= 96
                          ? null
                          : () => setState(() => _scale *= 2),
                      icon: Icons.zoom_in,
                    ),
                    if (widget.placementsOverride == null)
                      AppMenuButton<bool>(
                        key: const ValueKey("snapshot-preview-context"),
                        labelText: "Scene 顯示範圍",
                        value: _completeContext,
                        options: const [
                          DropdownOption(value: false, label: "相關 Scene"),
                          DropdownOption(value: true, label: "完整 Scene"),
                        ],
                        onChanged: (value) =>
                            setState(() => _completeContext = value!),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TimelineMiniView(
          placements: placements,
          currentTick: tick,
          minTick: widget.minTick ?? _min,
          maxTick: widget.maxTick ?? _max,
          pixelsPerTick: _scale,
          canvasKey: widget.canvasKey,
          showPlayhead: widget.mode != SnapshotPreviewMode.baseline,
          selectedMarkerId: _selectedId,
          markers: [
            for (final event in events)
              MiniTimelineMarker(
                id: event.id,
                tick: event.tick,
                label: event.description,
                color: event.inherited
                    ? Theme.of(context).colorScheme.outline
                    : null,
              ),
          ],
          onTickChanged: _canNavigate ? _pickTick : null,
          onMarkerGroupTap: !_canNavigate
              ? null
              : (markers) => _pickEvents([
                  for (final marker in markers)
                    events.firstWhere((e) => e.id == marker.id),
                ]),
          emptyMessage:
              widget.emptyMessage ??
              (events.isEmpty ? "尚無快照事件，可在任意 Tick 預覽" : "Scene 尚未排定，使用回退時間"),
        ),
        if (selected != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(selected.description),
          ),
        ],
      ],
    );
  }
}
