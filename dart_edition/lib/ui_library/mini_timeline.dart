import "dart:math" as math;

import "package:flutter/gestures.dart" show DragStartBehavior;
import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "spacing.dart";

/// A read-only interval occupying [startTick, endTick), like TimelineView.
@immutable
class MiniTimelineInterval {
  final String id;
  final String label;
  final int startTick;
  final int endTick;
  final String? trackId;
  final Color? color;

  const MiniTimelineInterval({
    required this.id,
    required this.startTick,
    required this.endTick,
    this.label = "",
    this.trackId,
    this.color,
  }) : assert(endTick > startTick);
}

/// A point in time, such as a snapshot or a bookmark.
@immutable
class MiniTimelineMarker {
  final String id;
  final int tick;
  final String label;
  final Color? color;

  const MiniTimelineMarker({
    required this.id,
    required this.tick,
    this.label = "",
    this.color,
  });
}

/// A compact, controlled Tick selector with rounded intervals and markers.
///
/// Omit bounds to fit the intervals, markers and current Tick. Overlapping
/// intervals get separate rows; additional rows scroll within the fixed height.
/// Set [pixelsPerTick] for horizontal scrolling with a visible Scrollbar.
/// Leave [onTickChanged] null for a read-only overview. Nodes cannot be moved
/// or resized. Both ends of the viewport are selectable, while interval ends
/// are exclusive. Keep the supplied lists immutable between builds.
class MiniTimeline extends StatefulWidget {
  final List<MiniTimelineInterval> intervals;
  final List<MiniTimelineMarker> markers;
  final int currentTick;
  final int? minTick;
  final int? maxTick;
  final ValueChanged<int>? onTickChanged;
  final ValueChanged<MiniTimelineMarker>? onMarkerTap;
  final ValueChanged<List<MiniTimelineMarker>>? onMarkerGroupTap;
  final String? selectedMarkerId;
  final bool showPlayhead;
  final double height;

  /// Null fits the viewport; a fixed scale enables horizontal scrolling.
  final double? pixelsPerTick;
  final String emptyMessage;
  final String semanticLabel;
  final Key? canvasKey;

  const MiniTimeline({
    super.key,
    this.intervals = const [],
    this.markers = const [],
    required this.currentTick,
    this.minTick,
    this.maxTick,
    this.onTickChanged,
    this.onMarkerTap,
    this.onMarkerGroupTap,
    this.selectedMarkerId,
    this.showPlayhead = true,
    this.height = 120,
    this.pixelsPerTick,
    this.emptyMessage = "尚無時間軸節點",
    this.semanticLabel = "微型時間軸",
    this.canvasKey,
  }) : assert(minTick == null || maxTick == null || minTick < maxTick),
       assert(height >= 80),
       assert(
         pixelsPerTick == null ||
             pixelsPerTick > 0 && pixelsPerTick < double.infinity,
       );

  @override
  State<MiniTimeline> createState() => _MiniTimelineState();
}

class _MiniTimelineState extends State<MiniTimeline> {
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _horizontalScrollController = ScrollController();
  _TickWindow? _dragWindow;
  _TickAxis? _activeAxis;
  int? _dragSelectedTick;
  double? _dragDisplayX;
  double _dragOriginGlobalX = 0;
  double _dragOriginDisplayX = 0;
  double _dragOriginScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scheduleReveal();
  }

  @override
  void didUpdateWidget(MiniTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onTickChanged != null && widget.onTickChanged == null) {
      _stopDrag();
    }
    if (widget.currentTick != oldWidget.currentTick ||
        widget.minTick != oldWidget.minTick ||
        widget.maxTick != oldWidget.maxTick ||
        widget.pixelsPerTick != oldWidget.pixelsPerTick) {
      _scheduleReveal();
    }
  }

  void _scheduleReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dragWindow == null) _revealTick();
    });
  }

  void _revealTick() {
    final axis = _activeAxis;
    if (axis == null || !_horizontalScrollController.hasClients) return;
    final position = _horizontalScrollController.position;
    final x = axis.x(widget.currentTick);
    if (x >= position.pixels + 24 &&
        x <= position.pixels + position.viewportDimension - 24) {
      return;
    }
    final target = (x - position.viewportDimension / 2).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _horizontalScrollController.jumpTo(target);
  }

  void _startDrag(_TickAxis axis, DragStartDetails details) {
    _focusNode.requestFocus();
    _dragWindow = axis.window;
    _dragSelectedTick = widget.currentTick.clamp(
      axis.window.min,
      axis.window.max,
    );
    _dragOriginGlobalX = details.globalPosition.dx;
    _dragOriginDisplayX = axis.x(_dragSelectedTick!);
    _dragOriginScrollOffset = _horizontalScrollController.hasClients
        ? _horizontalScrollController.offset
        : 0;
    setState(() => _dragDisplayX = _dragOriginDisplayX);
  }

  void _updateDrag(DragUpdateDetails details) {
    final axis = _activeAxis;
    final window = _dragWindow;
    if (axis == null || window == null) return;
    final scrollOffset = _horizontalScrollController.hasClients
        ? _horizontalScrollController.offset
        : 0.0;
    // Global pointer motion stays stable when the handle or viewport moves.
    final x =
        (_dragOriginDisplayX +
                details.globalPosition.dx -
                _dragOriginGlobalX +
                scrollOffset -
                _dragOriginScrollOffset)
            .clamp(axis.x(window.min), axis.x(window.max));
    final tick = axis.tickAt(x);
    final changed = tick != _dragSelectedTick;
    setState(() {
      _dragDisplayX = x;
      _dragSelectedTick = tick;
    });
    if (changed) _select(tick, window);
    if (_horizontalScrollController.hasClients) {
      final position = _horizontalScrollController.position;
      // Scroll only at the viewport edges; never recenter during a drag.
      final target = x < scrollOffset + 12
          ? x - 12
          : x > scrollOffset + position.viewportDimension - 12
          ? x - position.viewportDimension + 12
          : scrollOffset;
      _horizontalScrollController.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  void _stopDrag() {
    _dragWindow = null;
    _dragSelectedTick = null;
    _dragDisplayX = null;
  }

  void _endDrag() {
    setState(_stopDrag);
    _scheduleReveal();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _select(int tick, _TickWindow window) {
    widget.onTickChanged?.call(tick.clamp(window.min, window.max));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, _TickWindow window) {
    if (widget.onTickChanged == null ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final tick = widget.currentTick.clamp(window.min, window.max);
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => tick - 1,
      LogicalKeyboardKey.arrowRight => tick + 1,
      LogicalKeyboardKey.home => window.min,
      LogicalKeyboardKey.end => window.max,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    _select(next, window);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final labelStyle =
        (Theme.of(context).textTheme.labelSmall ??
                const TextStyle(fontSize: 11))
            .copyWith(color: scheme.onSurfaceVariant);
    final metrics = TextPainter(
      text: TextSpan(text: "${widget.currentTick}", style: labelStyle),
      textScaler: textScaler,
      textDirection: TextDirection.ltr,
    )..layout();
    final rulerHeight = math.max(36.0, metrics.height + AppSpacing.lg);
    metrics.dispose();
    final height = math.max(
      widget.height,
      rulerHeight + math.max(44, textScaler.scale(32)),
    );
    final window = _dragWindow ?? _TickWindow.forWidget(widget);
    final rows = _packRows(
      widget.intervals
          .where(
            (interval) =>
                interval.endTick > window.min &&
                interval.startTick < window.max,
          )
          .toList(),
    );
    final displayedTick = widget.currentTick.clamp(window.min, window.max);
    final interactive = widget.onTickChanged != null;

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: interactive,
      onFocusChange: (_) => setState(() {}),
      onKeyEvent: (node, event) => _onKey(node, event, window),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.semanticLabel,
        value: widget.showPlayhead ? "Tick ${widget.currentTick}" : "預設資料",
        slider: interactive && widget.showPlayhead,
        increasedValue:
            interactive && widget.showPlayhead && displayedTick < window.max
            ? "Tick ${displayedTick + 1}"
            : null,
        decreasedValue:
            interactive && widget.showPlayhead && displayedTick > window.min
            ? "Tick ${displayedTick - 1}"
            : null,
        onIncrease:
            interactive && widget.showPlayhead && displayedTick < window.max
            ? () => _select(displayedTick + 1, window)
            : null,
        onDecrease:
            interactive && widget.showPlayhead && displayedTick > window.min
            ? () => _select(displayedTick - 1, window)
            : null,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? scheme.primary
                  : scheme.outlineVariant,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The fallback also permits embedding in an unbounded Row.
                final width = constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : 320.0;
                final contentWidth = widget.pixelsPerTick == null
                    ? width
                    : math.max(
                        width,
                        (window.max - window.min) * widget.pixelsPerTick! +
                            AppSpacing.lg * 2,
                      );
                final axis = _TickAxis(window, contentWidth);
                _activeAxis = axis;
                void selectAt(Offset position) {
                  _focusNode.requestFocus();
                  _select(axis.tickAt(position.dx), window);
                }

                final visibleMarkers = widget.markers
                    .where((marker) => window.contains(marker.tick))
                    .toList();
                final markerTicks =
                    visibleMarkers.map((m) => m.tick).toSet().toList()..sort();
                return _horizontalViewport(
                  SizedBox(
                    width: contentWidth,
                    height: math.max(
                      0.0,
                      constraints.maxHeight - AppSpacing.md,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: interactive
                          ? (details) => selectAt(details.localPosition)
                          : null,
                      child: MouseRegion(
                        cursor: interactive
                            ? SystemMouseCursors.click
                            : MouseCursor.defer,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: scheme.surfaceContainerLowest,
                              ),
                            ),
                            Positioned(
                              top: rulerHeight,
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: rows.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.lg,
                                        ),
                                        child: Text(
                                          widget.emptyMessage,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: labelStyle,
                                        ),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      controller: _scrollController,
                                      child: SizedBox(
                                        height:
                                            rows.length * 20.0 + AppSpacing.sm,
                                        child: Stack(
                                          children: [
                                            for (
                                              var row = 0;
                                              row < rows.length;
                                              row++
                                            )
                                              for (final interval in rows[row])
                                                if (interval.endTick >
                                                        window.min &&
                                                    interval.startTick <
                                                        window.max)
                                                  _interval(
                                                    context,
                                                    interval,
                                                    row,
                                                    axis,
                                                  ),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _MiniTimelinePainter(
                                    axis: axis,
                                    horizontalScrollController:
                                        _horizontalScrollController,
                                    viewportWidth: width,
                                    currentTick:
                                        _dragSelectedTick ?? widget.currentTick,
                                    playheadX: _dragDisplayX,
                                    showPlayhead: widget.showPlayhead,
                                    selectedMarkerId: widget.selectedMarkerId,
                                    rulerHeight: rulerHeight,
                                    scheme: scheme,
                                    labelStyle: labelStyle,
                                    textScaler: textScaler,
                                    markers: visibleMarkers,
                                  ),
                                ),
                              ),
                            ),
                            // Markers at the same Tick share a target and tooltip.
                            for (final tick in markerTicks)
                              _markerTarget(
                                tick,
                                visibleMarkers,
                                axis,
                                rulerHeight,
                                markerTicks,
                              ),
                            if (interactive &&
                                widget.showPlayhead &&
                                window.contains(
                                  _dragSelectedTick ?? widget.currentTick,
                                ))
                              _scrubberHandle(axis, rulerHeight),
                          ],
                        ),
                      ),
                    ),
                  ),
                  width,
                  rows.isNotEmpty,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _horizontalViewport(Widget board, double width, bool hasRows) =>
      SizedBox(
        key: widget.canvasKey,
        width: width,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Scrollbar(
            key: const ValueKey("mini-timeline-vertical-scrollbar"),
            controller: _scrollController,
            thumbVisibility: hasRows,
            trackVisibility: hasRows,
            interactive: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.vertical,
            child: Scrollbar(
              key: const ValueKey("mini-timeline-horizontal-scrollbar"),
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: board,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _scrubberHandle(_TickAxis axis, double rulerHeight) => Positioned(
    left: (_dragDisplayX ?? axis.x(widget.currentTick)) - 12,
    top: 0,
    width: 24,
    height: rulerHeight,
    child: GestureDetector(
      key: const ValueKey("mini-timeline-scrubber"),
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onTap: () {
        final group = widget.markers
            .where((m) => m.tick == widget.currentTick)
            .toList();
        if (group.isEmpty) return;
        if (widget.onMarkerGroupTap != null) {
          widget.onMarkerGroupTap!(List.unmodifiable(group));
        } else {
          widget.onMarkerTap?.call(group.first);
        }
      },
      onHorizontalDragStart: (details) => _startDrag(axis, details),
      onHorizontalDragUpdate: _updateDrag,
      onHorizontalDragEnd: (_) => _endDrag(),
      onHorizontalDragCancel: _endDrag,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Tooltip(
          message: [
            "拖動目前時間：${_dragSelectedTick ?? widget.currentTick} Tick",
            ...widget.markers
                .where((m) => m.tick == widget.currentTick)
                .map((m) => m.label.isEmpty ? "時間標記" : m.label),
          ].join("\n"),
          child: Center(
            child: Icon(
              Icons.drag_indicator,
              size: 10,
              color: Theme.of(context).colorScheme.onTertiary,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _interval(
    BuildContext context,
    MiniTimelineInterval interval,
    int row,
    _TickAxis axis,
  ) {
    final left = axis.x(interval.startTick).clamp(0.0, axis.width);
    final right = axis.x(interval.endTick).clamp(0.0, axis.width);
    final label = interval.label.isEmpty ? "未命名節點" : interval.label;
    final description =
        "$label · Tick ${interval.startTick}–${interval.endTick - 1}";
    return Positioned(
      left: left,
      top: AppSpacing.xs + row * 20.0,
      width: math.max(1.0, right - left),
      height: 16,
      child: Tooltip(
        message: description,
        waitDuration: const Duration(milliseconds: 300),
        child: Semantics(
          label: description,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  interval.color ??
                  Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _markerTarget(
    int tick,
    List<MiniTimelineMarker> markers,
    _TickAxis axis,
    double rulerHeight,
    List<int> markerTicks,
  ) {
    final group = markers.where((marker) => marker.tick == tick).toList();
    final description = group
        .map((m) => "${m.label.isEmpty ? '時間標記' : m.label} · Tick $tick")
        .join("\n");
    final canTap =
        widget.onMarkerTap != null ||
        widget.onMarkerGroupTap != null ||
        widget.onTickChanged != null;
    final index = markerTicks.indexOf(tick);
    final center = axis.x(tick);
    final left = math.max(
      0.0,
      math.max(
        center - 20,
        index == 0 ? 0.0 : (axis.x(markerTicks[index - 1]) + center) / 2,
      ),
    );
    final right = math.min(
      axis.width,
      math.min(
        center + 20,
        index == markerTicks.length - 1
            ? axis.width
            : (center + axis.x(markerTicks[index + 1])) / 2,
      ),
    );
    return Positioned(
      left: left,
      top: 0,
      width: math.max(0.0, right - left),
      height: rulerHeight,
      child: Tooltip(
        key: ValueKey("mini-timeline-marker-$tick"),
        message: description,
        child: Semantics(
          label: description,
          button: canTap,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canTap
                ? () {
                    _focusNode.requestFocus();
                    _select(tick, axis.window);
                    if (widget.onMarkerGroupTap != null) {
                      widget.onMarkerGroupTap!(List.unmodifiable(group));
                    } else {
                      widget.onMarkerTap?.call(group.first);
                    }
                  }
                : null,
          ),
        ),
      ),
    );
  }
}

List<List<MiniTimelineInterval>> _packRows(
  List<MiniTimelineInterval> intervals,
) {
  final tracks = <String?, List<MiniTimelineInterval>>{};
  for (final interval in intervals) {
    if (interval.endTick <= interval.startTick) continue;
    tracks.putIfAbsent(interval.trackId, () => []).add(interval);
  }
  final result = <List<MiniTimelineInterval>>[];
  for (final track in tracks.values) {
    track.sort((a, b) {
      final start = a.startTick.compareTo(b.startTick);
      return start != 0 ? start : a.id.compareTo(b.id);
    });
    final rows = <List<MiniTimelineInterval>>[];
    for (final interval in track) {
      final row = rows
          .where((row) => row.last.endTick <= interval.startTick)
          .firstOrNull;
      if (row == null) {
        rows.add([interval]);
      } else {
        row.add(interval);
      }
    }
    result.addAll(rows);
  }
  return result;
}

class _TickWindow {
  final int min;
  final int max;

  const _TickWindow(this.min, this.max);

  factory _TickWindow.forWidget(MiniTimeline widget) {
    var min = widget.currentTick;
    var max = widget.currentTick;
    for (final interval in widget.intervals) {
      min = math.min(min, interval.startTick);
      max = math.max(max, interval.endTick);
    }
    for (final marker in widget.markers) {
      min = math.min(min, marker.tick);
      max = math.max(max, marker.tick);
    }
    min = widget.minTick ?? min - 1;
    max = widget.maxTick ?? max + 1;
    if (max <= min) {
      if (widget.maxTick != null && widget.minTick == null) {
        min = max - 1;
      } else {
        max = min + 1;
      }
    }
    return _TickWindow(min, max);
  }

  bool contains(int tick) => tick >= min && tick <= max;
}

class _TickAxis {
  final _TickWindow window;
  final double width;

  const _TickAxis(this.window, this.width);

  double get inset => math.min(AppSpacing.lg, width / 4);
  double get usableWidth => math.max(1.0, width - inset * 2);
  double x(int tick) =>
      inset + (tick - window.min) / (window.max - window.min) * usableWidth;
  int tickAt(double x) =>
      window.min +
      (((x - inset) / usableWidth).clamp(0.0, 1.0) * (window.max - window.min))
          .round();
}

class _MiniTimelinePainter extends CustomPainter {
  final _TickAxis axis;
  final ScrollController horizontalScrollController;
  final double viewportWidth;
  final int currentTick;
  final double? playheadX;
  final bool showPlayhead;
  final String? selectedMarkerId;
  final double rulerHeight;
  final ColorScheme scheme;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final List<MiniTimelineMarker> markers;

  _MiniTimelinePainter({
    required this.axis,
    required this.horizontalScrollController,
    required this.viewportWidth,
    required this.currentTick,
    this.playheadX,
    this.showPlayhead = true,
    this.selectedMarkerId,
    required this.rulerHeight,
    required this.scheme,
    required this.labelStyle,
    required this.textScaler,
    required this.markers,
  }) : super(repaint: horizontalScrollController);

  @override
  void paint(Canvas canvas, Size size) {
    final offset = horizontalScrollController.hasClients
        ? horizontalScrollController.offset
        : 0.0;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(offset, 0, viewportWidth, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, rulerHeight),
      Paint()..color = scheme.surfaceContainerHigh,
    );
    final text = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );
    double measure(String label) {
      text.text = TextSpan(text: label, style: labelStyle);
      text.layout();
      return text.width;
    }

    final spacing = math.max(
      40.0,
      math.max(measure("${axis.window.min}"), measure("${axis.window.max}")) +
          16,
    );
    final labelCount = math.max(1, (axis.usableWidth / spacing).floor());
    final rawStep = (axis.window.max - axis.window.min) / labelCount;
    final magnitude = math
        .pow(10, (math.log(rawStep) / math.ln10).floor())
        .toDouble();
    final fraction = rawStep / magnitude;
    final multiplier = fraction <= 1
        ? 1
        : fraction <= 2
        ? 2
        : fraction <= 5
        ? 5
        : 10;
    final step = math.max(1, (multiplier * magnitude).ceil());
    final firstTick =
        (math.max(axis.window.min, axis.tickAt(offset) - step) / step).ceil() *
        step;
    final lastTick = math.min(
      axis.window.max,
      axis.tickAt(offset + viewportWidth) + step,
    );
    final indicatorXs = [
      if (showPlayhead && axis.window.contains(currentTick))
        playheadX ?? axis.x(currentTick),
      ...markers.map((m) => axis.x(m.tick)),
    ];
    var previousRight = double.negativeInfinity;
    for (var tick = firstTick; tick <= lastTick; tick += step) {
      final x = axis.x(tick);
      text.text = TextSpan(text: "$tick", style: labelStyle);
      text.layout();
      if (text.width > size.width - AppSpacing.sm) continue;
      final left = math.min(
        x + AppSpacing.sm,
        size.width - AppSpacing.xs - text.width,
      );
      if (left < previousRight + AppSpacing.xs) continue;
      if (indicatorXs.any((x) => x + 8 > left && x - 8 < left + text.width)) {
        continue;
      }
      text.paint(canvas, Offset(left, (rulerHeight - text.height) / 2));
      previousRight = left + text.width;
    }
    text.dispose();
    for (final marker in markers) {
      final x = axis.x(marker.tick);
      final y = rulerHeight / 2;
      final radius = marker.tick == currentTick ? 10.0 : 7.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, y - radius)
          ..lineTo(x + radius, y)
          ..lineTo(x, y + radius)
          ..lineTo(x - radius, y)
          ..close(),
        Paint()..color = marker.color ?? scheme.secondary,
      );
      if (marker.id == selectedMarkerId) {
        canvas.drawCircle(
          Offset(x, y),
          11,
          Paint()
            ..color = scheme.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    if (showPlayhead && axis.window.contains(currentTick)) {
      final x = playheadX ?? axis.x(currentTick);
      final y = rulerHeight / 2;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, size.height),
        Paint()
          ..color = scheme.tertiary
          ..strokeWidth = 2,
      );
      canvas.drawCircle(Offset(x, y), 7, Paint()..color = scheme.tertiary);
      canvas.drawCircle(
        Offset(x, y),
        7,
        Paint()
          ..color = scheme.surfaceContainerLowest
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniTimelinePainter oldDelegate) =>
      axis.window.min != oldDelegate.axis.window.min ||
      axis.window.max != oldDelegate.axis.window.max ||
      axis.width != oldDelegate.axis.width ||
      viewportWidth != oldDelegate.viewportWidth ||
      horizontalScrollController != oldDelegate.horizontalScrollController ||
      currentTick != oldDelegate.currentTick ||
      playheadX != oldDelegate.playheadX ||
      showPlayhead != oldDelegate.showPlayhead ||
      selectedMarkerId != oldDelegate.selectedMarkerId ||
      rulerHeight != oldDelegate.rulerHeight ||
      scheme != oldDelegate.scheme ||
      labelStyle != oldDelegate.labelStyle ||
      textScaler != oldDelegate.textScaler ||
      markers != oldDelegate.markers;
}
