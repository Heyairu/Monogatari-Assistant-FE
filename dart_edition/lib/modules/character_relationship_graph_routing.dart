import "dart:math" as math;
import "package:flutter/material.dart";
import "character_relationship_graph_mapper.dart";

class EdgeLabelPlacement {
  final Offset center;
  final Size size;
  final bool visible;

  const EdgeLabelPlacement({
    required this.center,
    required this.size,
    this.visible = true,
  });
}

class EdgeVisualLayout {
  final EdgeGeometry geometry;
  final EdgeLabelPlacement label;

  const EdgeVisualLayout({required this.geometry, required this.label});
}

/// Routing uses all four reserved lanes even when some channels are hidden.
/// Focus and labels therefore never change the actual line geometry.
Map<String, EdgeVisualLayout> routeCharacterEdges(
  List<CharacterRelationshipGraphEdge> edges,
  Map<String, Offset> positions,
  Size canvasSize, {
  required Size nodeSize,
  required Map<String, Size> labelSizes,
  required Set<String> labeledEdgeIds,
}) => placeCharacterEdgeLabels(
  edges,
  routeCharacterEdgeGeometries(
    edges,
    positions,
    canvasSize,
    nodeSize: nodeSize,
  ),
  positions,
  canvasSize,
  nodeSize: nodeSize,
  labelSizes: labelSizes,
  labeledEdgeIds: labeledEdgeIds,
);

Map<String, EdgeGeometry> routeCharacterEdgeGeometries(
  List<CharacterRelationshipGraphEdge> edges,
  Map<String, Offset> positions,
  Size canvasSize, {
  required Size nodeSize,
}) {
  final nodes = {
    for (final entry in positions.entries) entry.key: (entry.value & nodeSize),
  };
  final result = <String, EdgeGeometry>{};
  final detours = <String, double>{};
  final pairs = <String, CharacterRelationshipGraphEdge>{};
  for (final edge in edges) {
    pairs.putIfAbsent(
      "${edge.canonicalSource}::${edge.canonicalTarget}",
      () => edge,
    );
  }
  for (final entry in pairs.entries) {
    final edge = entry.value;
    if (edge.canonicalSource == edge.canonicalTarget) {
      detours[entry.key] = 0;
      continue;
    }
    final start =
        positions[edge.canonicalSource]! +
        Offset(nodeSize.width / 2, nodeSize.height / 2);
    final end =
        positions[edge.canonicalTarget]! +
        Offset(nodeSize.width / 2, nodeSize.height / 2);
    final delta = end - start;
    final normal = Offset(-delta.dy, delta.dx) / math.max(1.0, delta.distance);
    final obstacles = nodes.entries
        .where(
          (e) => e.key != edge.canonicalSource && e.key != edge.canonicalTarget,
        )
        .map((e) => e.value.inflate(18))
        .toList();
    var best = 0.0;
    var bestScore = double.infinity;
    final limit = math.max(
      360.0,
      math.min(1800.0, canvasSize.longestSide * .65),
    );
    final offsets = <double>[
      0,
      for (var n = 72.0; n <= limit; n += 72) ...[n, -n],
    ];
    for (final detour in offsets) {
      var score = detour.abs() * .02;
      for (final lane in [-90.0, -30.0, 30.0, 90.0]) {
        final control = (start + end) / 2 + normal * (lane + detour);
        final from = start + nodeBoundaryOffset(control - start, nodeSize);
        final to = end + nodeBoundaryOffset(control - end, nodeSize);
        for (var sample = 1; sample < 64; sample++) {
          final point = quadraticPoint(from, control, to, sample / 64);
          if (obstacles.any((r) => r.contains(point))) score += 100000;
          if (point.dx < 8 ||
              point.dy < 8 ||
              point.dx > canvasSize.width - 8 ||
              point.dy > canvasSize.height - 8) {
            score += 1000000;
          }
        }
      }
      if (score < bestScore) {
        bestScore = score;
        best = detour;
      }
      if (score < 100000) break;
    }
    detours[entry.key] = best;
  }
  for (final edge in edges) {
    var geometry = edgeGeometry(edge, edges, positions, nodeSize: nodeSize);
    if (edge.sourceCharacterId != edge.targetNodeId) {
      final canonicalStart = positions[edge.canonicalSource]!;
      final canonicalEnd = positions[edge.canonicalTarget]!;
      final delta = canonicalEnd - canonicalStart;
      final normal =
          Offset(-delta.dy, delta.dx) / math.max(1.0, delta.distance);
      final control =
          geometry.control +
          normal * detours["${edge.canonicalSource}::${edge.canonicalTarget}"]!;
      final source =
          positions[edge.sourceCharacterId]! +
          Offset(nodeSize.width / 2, nodeSize.height / 2);
      final target =
          positions[edge.targetNodeId]! +
          Offset(nodeSize.width / 2, nodeSize.height / 2);
      final from = source + nodeBoundaryOffset(control - source, nodeSize);
      final to = target + nodeBoundaryOffset(control - target, nodeSize);
      geometry = EdgeGeometry(
        start: from,
        control: control,
        end: to,
        label: quadraticPoint(from, control, to, .5),
      );
    }
    result[edge.id] = geometry;
  }
  return result;
}

/// Label placement can change with focus without recalculating obstacle routes.
Map<String, EdgeVisualLayout> placeCharacterEdgeLabels(
  List<CharacterRelationshipGraphEdge> edges,
  Map<String, EdgeGeometry> geometries,
  Map<String, Offset> positions,
  Size canvasSize, {
  required Size nodeSize,
  required Map<String, Size> labelSizes,
  required Set<String> labeledEdgeIds,
}) {
  final nodes = {
    for (final entry in positions.entries) entry.key: (entry.value & nodeSize),
  };
  final occupiedLabels = <Rect>[];
  final result = <String, EdgeVisualLayout>{};
  double overlap(Rect candidate, Iterable<Rect> obstacles) {
    var area = 0.0;
    for (final rect in obstacles) {
      final intersection = rect.intersect(candidate);
      if (intersection.width > 0 && intersection.height > 0) {
        area += intersection.width * intersection.height;
      }
    }
    return area;
  }

  for (final edge in edges) {
    final geometry = geometries[edge.id]!;
    final labelSize = labelSizes[edge.id]!;
    final preferredT = edge.layer == CharacterRelationshipLayer.external
        ? .34
        : .66;
    final ts = <double>[
      preferredT,
      for (var step = 4; step <= 21; step++) step / 25,
    ]..sort((a, b) => (a - preferredT).abs().compareTo((b - preferredT).abs()));
    var center = geometry.label;
    var bestScore = double.infinity;
    for (final t in ts) {
      final candidateCenter = quadraticPoint(
        geometry.start,
        geometry.control,
        geometry.end,
        t,
      );
      final rect = Rect.fromCenter(
        center: candidateCenter,
        width: labelSize.width,
        height: labelSize.height,
      );
      final boundary =
          rect.left < 8 ||
          rect.top < 8 ||
          rect.right > canvasSize.width - 8 ||
          rect.bottom > canvasSize.height - 8;
      final score =
          overlap(rect, nodes.values.map((r) => r.inflate(24))) * 4 +
          overlap(rect, occupiedLabels) * 8 +
          (boundary ? 1000000 : 0) +
          (t - preferredT).abs();
      if (score < bestScore) {
        center = candidateCenter;
        bestScore = score;
      }
    }
    final visible = bestScore < 1;
    result[edge.id] = EdgeVisualLayout(
      geometry: geometry,
      label: EdgeLabelPlacement(
        center: center,
        size: labelSize,
        visible: visible,
      ),
    );
    if (visible && labeledEdgeIds.contains(edge.id)) {
      occupiedLabels.add(
        Rect.fromCenter(
          center: center,
          width: labelSize.width,
          height: labelSize.height,
        ).inflate(5),
      );
    }
  }
  return result;
}

class EdgeGeometry {
  final Offset start;
  final Offset control;
  final Offset end;
  final Offset label;

  const EdgeGeometry({
    required this.start,
    required this.control,
    required this.end,
    required this.label,
  });
}

Offset nodeBoundaryOffset(Offset direction, Size nodeSize) {
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

EdgeGeometry edgeGeometry(
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

  final centerDelta = target - source;
  final centerDistance = math.max(1.0, centerDelta.distance);
  final centerDirection = centerDelta / centerDistance;

  if (edge.sourceCharacterId == edge.targetNodeId) {
    final shift = edge.layer == CharacterRelationshipLayer.external
        ? 0.0
        : 48.0;
    final sign = source.dy > nodeSize.height + 188 ? -1.0 : 1.0;
    final start =
        source + Offset(-nodeSize.width * .32, sign * nodeSize.height / 2);
    final end =
        source + Offset(nodeSize.width * .32, sign * nodeSize.height / 2);
    final control = source + Offset(0, sign * (nodeSize.height + 140 + shift));
    return EdgeGeometry(
      start: start,
      control: control,
      end: end,
      label: quadraticPoint(start, control, end, .5),
    );
  }
  final canonicalDirection =
      centerDirection *
      (edge.sourceCharacterId == edge.canonicalSource ? 1 : -1);
  final normal = Offset(-canonicalDirection.dy, canonicalDirection.dx);
  final laneOffset = edge.isBidirectional
      ? (edge.layer == CharacterRelationshipLayer.external ? -90.0 : -30.0)
      : const [-90.0, -30.0, 30.0, 90.0][edge.lane];
  final control = (source + target) / 2 + normal * laneOffset;
  final start = source + nodeBoundaryOffset(control - source, nodeSize);
  final end = target + nodeBoundaryOffset(control - target, nodeSize);
  final label = quadraticPoint(start, control, end, .5);

  return EdgeGeometry(start: start, control: control, end: end, label: label);
}

Offset quadraticPoint(Offset start, Offset control, Offset end, double t) {
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
