import "dart:math" as math;

import "package:flutter/material.dart";

import "character_relationship_graph_mapper.dart";

enum CharacterGraphLayoutMode { roles, clusters }

class CharacterGraphLayoutResult {
  final Map<String, Offset> positions;
  final Size canvasSize;
  const CharacterGraphLayoutResult(this.positions, this.canvasSize);
}

/// Session-owned positions are separate from character data and visual channels.
class CharacterGraphLayoutSession {
  final Map<CharacterGraphLayoutMode, Map<String, Offset>> _positions = {};
  final Set<String> pinned = {};
  final Map<String, Offset> _pinnedPositions = {};
  CharacterGraphLayoutMode _activeMode = CharacterGraphLayoutMode.roles;
  int revision = 0;
  void clear() {
    _positions.clear();
    pinned.clear();
    _pinnedPositions.clear();
    revision++;
  }

  void togglePin(String id) {
    if (pinned.remove(id)) {
      _pinnedPositions.remove(id);
    } else {
      pinned.add(id);
      final position = _positions[_activeMode]?[id];
      if (position != null) _pinnedPositions[id] = position;
    }
    revision++;
  }

  void move(CharacterGraphLayoutMode mode, String id, Offset position) {
    final next = Offset(math.max(24, position.dx), math.max(24, position.dy));
    _positions[mode]?[id] = next;
    if (pinned.contains(id)) _pinnedPositions[id] = next;
    revision++;
  }

  void rearrange(CharacterGraphLayoutMode mode) {
    _positions[mode]?.removeWhere((id, _) => !pinned.contains(id));
    revision++;
  }

  CharacterGraphLayoutResult resolve(
    CharacterRelationshipGraphData graph,
    CharacterGraphLayoutMode mode,
    Size nodeSize, {
    int layoutRevision = 0,
  }) {
    final switchedMode = _activeMode != mode;
    _activeMode = mode;
    final existing = _positions.putIfAbsent(mode, () => {});
    final ids = graph.nodes.map((n) => n.id).toSet();
    existing.removeWhere((id, _) => !ids.contains(id));
    pinned.removeWhere((id) => !ids.contains(id));
    _pinnedPositions.removeWhere((id, _) => !ids.contains(id));
    for (final id in pinned) {
      if (_pinnedPositions.containsKey(id)) {
        existing[id] = _pinnedPositions[id]!;
        continue;
      }
      if (!existing.containsKey(id)) {
        for (final other in _positions.values) {
          if (other.containsKey(id)) {
            existing[id] = other[id]!;
            break;
          }
        }
      }
    }
    if (switchedMode) {
      final pinRects = [
        for (final id in pinned)
          if (existing.containsKey(id)) (existing[id]! & nodeSize).inflate(40),
      ];
      existing.removeWhere(
        (id, position) =>
            !pinned.contains(id) &&
            pinRects.any((rect) => rect.overlaps(position & nodeSize)),
      );
    }
    final missing = graph.nodes
        .where((n) => !existing.containsKey(n.id))
        .toList();
    final seeds = missing.isEmpty
        ? <String, Offset>{}
        : mode == CharacterGraphLayoutMode.roles
        ? CharacterRoleLayout(nodeSize, layoutRevision).positions(graph)
        : _clusterPositions(graph, nodeSize);
    final neighbors = {for (final id in ids) id: <String>{}};
    for (final edge in graph.topologyEdges) {
      if (edge.sourceCharacterId == edge.targetNodeId) continue;
      neighbors[edge.sourceCharacterId]?.add(edge.targetNodeId);
      neighbors[edge.targetNodeId]?.add(edge.sourceCharacterId);
    }
    double clearance(String id) => (neighbors[id]?.length ?? 0) > 6
        ? math.min(80.0, neighbors[id]!.length * 3.0)
        : 0;
    // Existing positions (including manual overlap) remain fixed until rearrange.
    final occupied = [
      for (final entry in existing.entries)
        (entry.value & nodeSize).inflate(clearance(entry.key)),
    ];
    final priority = [...missing]
      ..sort((a, b) {
        final aHero =
            a.character?.characterType == "主角" ||
            a.character?.characterType == "主要反派";
        final bHero =
            b.character?.characterType == "主角" ||
            b.character?.characterType == "主要反派";
        if (aHero != bHero) return aHero ? -1 : 1;
        return a.id.compareTo(b.id);
      });
    for (final node in priority) {
      var preferred = seeds[node.id] ?? const Offset(80, 80);
      if (!node.isUnresolved &&
          existing.isNotEmpty &&
          missing.length < graph.nodes.length) {
        for (final edge in graph.topologyEdges) {
          final neighbor = edge.sourceCharacterId == node.id
              ? edge.targetNodeId
              : edge.targetNodeId == node.id
              ? edge.sourceCharacterId
              : null;
          if (existing.containsKey(neighbor)) {
            preferred = existing[neighbor]! + Offset(nodeSize.width + 100, 0);
            break;
          }
        }
      }
      final position = _vacantPosition(
        preferred,
        nodeSize,
        occupied,
        clearance: clearance(node.id),
      );
      existing[node.id] = position;
      occupied.add((position & nodeSize).inflate(clearance(node.id)));
    }
    var width = 900.0;
    var height = 700.0;
    for (final p in existing.values) {
      width = math.max(width, p.dx + nodeSize.width + 160);
      height = math.max(height, p.dy + nodeSize.height + 160);
    }
    return CharacterGraphLayoutResult(
      Map.unmodifiable(existing),
      Size(width, height),
    );
  }
}

Offset _vacantPosition(
  Offset preferred,
  Size size,
  List<Rect> occupied, {
  double clearance = 0,
}) {
  bool vacant(Offset p) =>
      p.dx >= 24 &&
      p.dy >= 24 &&
      !occupied.any(
        (r) => r.inflate(40).overlaps((p & size).inflate(clearance)),
      );
  if (vacant(preferred)) return preferred;
  // Expanding rectangular rings always find space, without shrinking node gaps.
  final step = math.max(size.width, size.height) + 56;
  for (var ring = 1; ring <= 24; ring++) {
    for (var x = -ring; x <= ring; x++) {
      for (final y in [-ring, ring]) {
        final p = preferred + Offset(x * step, y * step);
        if (vacant(p)) return p;
      }
    }
    for (var y = -ring + 1; y < ring; y++) {
      for (final x in [-ring, ring]) {
        final p = preferred + Offset(x * step, y * step);
        if (vacant(p)) return p;
      }
    }
  }
  final right = occupied.fold<double>(
    24,
    (maximum, rect) => math.max(maximum, rect.right),
  );
  return Offset(right + 56 + clearance, math.max(24, preferred.dy));
}

Map<String, Offset> _clusterPositions(
  CharacterRelationshipGraphData graph,
  Size size,
) {
  final neighbors = {
    for (final node in graph.nodes)
      if (!node.isUnresolved) node.id: <String>{},
  };
  for (final edge in graph.topologyEdges) {
    if (edge.sourceCharacterId == edge.targetNodeId ||
        !neighbors.containsKey(edge.sourceCharacterId) ||
        !neighbors.containsKey(edge.targetNodeId)) {
      continue;
    }
    neighbors[edge.sourceCharacterId]?.add(edge.targetNodeId);
    neighbors[edge.targetNodeId]?.add(edge.sourceCharacterId);
  }
  final remaining = neighbors.keys.toList()..sort();
  final visited = <String>{};
  final groups = <List<String>>[];
  for (final root in remaining) {
    if (!visited.add(root)) continue;
    final members = <String>[root];
    for (var i = 0; i < members.length; i++) {
      for (final id in neighbors[members[i]]!.toList()..sort()) {
        if (visited.add(id)) members.add(id);
      }
    }
    members.sort((a, b) {
      final degree = neighbors[b]!.length.compareTo(neighbors[a]!.length);
      return degree != 0 ? degree : a.compareTo(b);
    });
    groups.add(members);
  }
  groups.sort((a, b) {
    final count = b.length.compareTo(a.length);
    return count != 0 ? count : a.first.compareTo(b.first);
  });
  final result = <String, Offset>{};
  var left = 160.0;
  var top = 160.0;
  var rowHeight = 0.0;
  for (final members in groups.where((group) => group.length > 1)) {
    final radius = math.max(
      160.0,
      members.length * (size.longestSide + 60) / (2 * math.pi),
    );
    final extent = radius * 2 + size.longestSide + 180;
    if (left > 160 && left + extent > 2400) {
      left = 160;
      top += rowHeight + 200;
      rowHeight = 0;
    }
    final center = Offset(left + radius, top + radius);
    final local = <String, Offset>{members.first: center};
    for (var i = 1; i < members.length; i++) {
      local[members[i]] =
          center +
          Offset.fromDirection(
            2 * math.pi * (i - 1) / (members.length - 1),
            radius,
          );
    }
    // Bounded deterministic relaxation uses one neighbor per character pair.
    for (var iteration = 0; iteration < 60; iteration++) {
      final next = <String, Offset>{};
      for (final id in members) {
        var force = (center - local[id]!) * 0.015;
        for (final other in members) {
          if (other == id) continue;
          final delta = local[id]! - local[other]!;
          final distance = math.max(1.0, delta.distance);
          final direction = delta / distance;
          force += direction * (12000 / (distance * distance));
          if (neighbors[id]!.contains(other)) {
            force -= direction * ((distance - size.longestSide - 100) * 0.025);
          }
        }
        if (force.distance > 16) force = force / force.distance * 16;
        next[id] = local[id]! + force;
      }
      local.addAll(next);
    }
    result.addAll(local);
    left += extent + 200;
    rowHeight = math.max(rowHeight, extent);
  }
  // Compact shelves for isolated characters, then a separate unresolved area.
  var shelfTop = result.values.fold<double>(
    160,
    (maximum, point) => math.max(maximum, point.dy + size.height + 160),
  );
  void addShelf(List<String> ids) {
    ids.sort();
    const columns = 8;
    for (var index = 0; index < ids.length; index++) {
      result[ids[index]] = Offset(
        160 + (index % columns) * (size.width + 80),
        shelfTop + (index ~/ columns) * (size.height + 80),
      );
    }
    if (ids.isNotEmpty) {
      shelfTop +=
          ((ids.length + columns - 1) ~/ columns) * (size.height + 80) + 120;
    }
  }

  addShelf(
    groups.where((group) => group.length == 1).map((g) => g.first).toList(),
  );
  addShelf(
    graph.nodes.where((node) => node.isUnresolved).map((n) => n.id).toList(),
  );
  return result;
}

enum _CharacterLayoutLane {
  other,
  secondarySupporting,
  importantSupporting,
  protagonist,
  mainVillain,
  secondaryVillain,
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

class CharacterRoleLayout {
  final Size nodeSize;
  final int layoutRevision;
  const CharacterRoleLayout(this.nodeSize, this.layoutRevision);
  Map<String, Offset> positions(CharacterRelationshipGraphData graph) =>
      _layoutNodes(graph, graph.nodes.map((n) => n.id).toSet());
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
        final labelOrder = left.label.toLowerCase().compareTo(
          right.label.toLowerCase(),
        );
        return labelOrder != 0 ? labelOrder : left.id.compareTo(right.id);
      });
      if (laneNodes.isNotEmpty) {
        final shift = layoutRevision % laneNodes.length;
        laneNodes.addAll(laneNodes.take(shift));
        laneNodes.removeRange(0, shift);
      }
    }
    return lanes;
  }

  double _ringRadius(
    int nodeCount, {
    required double minimum,
    bool allowSingleAtCenter = false,
  }) {
    if (nodeCount == 0) return 0;
    if (allowSingleAtCenter && nodeCount == 1) return 0;
    if (nodeCount == 1) return minimum;
    // Chord capacity includes the full rectangle at every angular position.
    final clearance =
        math.sqrt(
          nodeSize.width * nodeSize.width + nodeSize.height * nodeSize.height,
        ) +
        40;
    return math.max(minimum, clearance / (2 * math.sin(math.pi / nodeCount)));
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

    // A group's allocated sector must accommodate its chord spacing. Increase
    // radius instead of squeezing the members into an undersized angular span.
    void expandSectors(List<_CharacterLayoutLane> clusterLanes) {
      final weights = <String, int>{};
      for (final lane in clusterLanes) {
        final counts = <String, int>{};
        for (final node in lanes[lane]!) {
          counts.update(
            _layoutOrganizationKey(node),
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        }
        for (final entry in counts.entries) {
          weights[entry.key] = math.max(weights[entry.key] ?? 0, entry.value);
        }
      }
      if (weights.length <= 1) return;
      final total = weights.values.fold<int>(0, (a, b) => a + b);
      final sectorGap = math.min(.24, math.pi / (weights.length * 4));
      final available = 2 * math.pi - sectorGap * weights.length;
      var previous = 0.0;
      for (final lane in clusterLanes) {
        if (lanes[lane]!.isEmpty) continue;
        if (radii[lane] == 0) continue;
        var radius = radii[lane]!;
        final counts = <String, int>{};
        for (final node in lanes[lane]!) {
          counts.update(
            _layoutOrganizationKey(node),
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        }
        for (final entry in counts.entries) {
          if (entry.value <= 1) continue;
          final span = available * weights[entry.key]! / total * .8;
          final angle = math.min(math.pi / 2, span / (entry.value - 1) / 2);
          radius = math.max(
            radius,
            (nodeSize.width + 80) / (2 * math.sin(angle)),
          );
        }
        radius = math.max(
          radius,
          previous == 0 ? 0 : previous + nodeSize.longestSide + 100,
        );
        radii[lane] = radius;
        previous = radius;
      }
    }

    expandSectors(const [
      _CharacterLayoutLane.protagonist,
      _CharacterLayoutLane.importantSupporting,
      _CharacterLayoutLane.secondarySupporting,
      _CharacterLayoutLane.other,
    ]);
    expandSectors(const [
      _CharacterLayoutLane.mainVillain,
      _CharacterLayoutLane.secondaryVillain,
    ]);

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
          nodeSize.width / 2 +
          64,
    );
    final villainExtent = math.max(
      310.0,
      maximumRadius(const [
            _CharacterLayoutLane.mainVillain,
            _CharacterLayoutLane.secondaryVillain,
          ]) +
          nodeSize.width / 2 +
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
      ((canvasWidth - 48) / (nodeSize.width + 28)).floor(),
    );
    final unresolvedRows = (unresolvedCount / unresolvedColumns).ceil();
    final unresolvedHeight = unresolvedRows == 0
        ? 0.0
        : unresolvedRows * (nodeSize.height + 24) + 28;

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
    for (final edge in graph.topologyEdges) {
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
      ((canvasSize.width - 48) / (nodeSize.width + 28)).floor(),
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
                      math.min(0.95, (nodeSize.width + 80) / (2 * radius)),
                    );
          final spread = laneMembers.length <= 1
              ? 0.0
              : minimumGap * (laneMembers.length - 1);
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
            nodeCenter - Offset(nodeSize.width / 2, nodeSize.height / 2);
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
        24 + column * (nodeSize.width + 28),
        metrics.resolvedHeight + row * (nodeSize.height + 24) + 12,
      );
    }
    return positions;
  }
}
