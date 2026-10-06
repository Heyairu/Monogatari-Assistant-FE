import "package:flutter/material.dart";

import "../../models/timeline_data.dart";
import "../../ui_library/mini_timeline.dart";

/// Adapts TimelineView placements to the reusable miniature timeline.
///
/// The caller chooses the scope and owns the cursor, so snapshot dialogs can
/// preview a local Tick without changing the project's global playhead.
class TimelineMiniView extends StatelessWidget {
  final List<TimelinePlacementData> placements;
  final List<MiniTimelineMarker> markers;
  final int currentTick;
  final int? minTick;
  final int? maxTick;
  final ValueChanged<int>? onTickChanged;
  final ValueChanged<MiniTimelineMarker>? onMarkerTap;
  final double height;
  final double pixelsPerTick;
  final String emptyMessage;
  final String semanticLabel;
  final Key? canvasKey;

  const TimelineMiniView({
    super.key,
    required this.placements,
    required this.currentTick,
    this.markers = const [],
    this.minTick,
    this.maxTick,
    this.onTickChanged,
    this.onMarkerTap,
    this.height = 120,
    this.pixelsPerTick = 48,
    this.emptyMessage = "尚無時間軸節點",
    this.semanticLabel = "微型時間軸",
    this.canvasKey,
  });

  @override
  Widget build(BuildContext context) => MiniTimeline(
    intervals: [
      for (final placement in placements)
        MiniTimelineInterval(
          id: placement.placementUUID,
          label: placement.label,
          startTick: placement.startTick,
          endTick: placement.endTick,
          trackId: placement.trackUUID,
        ),
    ],
    markers: markers,
    currentTick: currentTick,
    minTick: minTick,
    maxTick: maxTick,
    onTickChanged: onTickChanged,
    onMarkerTap: onMarkerTap,
    height: height,
    pixelsPerTick: pixelsPerTick,
    emptyMessage: emptyMessage,
    semanticLabel: semanticLabel,
    canvasKey: canvasKey,
  );
}
