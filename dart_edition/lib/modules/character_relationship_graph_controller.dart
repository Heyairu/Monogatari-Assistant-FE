import "dart:math" as math;

import "package:flutter/material.dart";

import "character_relationship_graph_mapper.dart";

class CharacterRelationshipGraphController extends ChangeNotifier {
  final TransformationController transformationController =
      TransformationController();
  String? selectedNodeId;
  String? selectedEdgeId;
  bool neighborsOnly = false;
  int layoutRevision = 0;

  void selectNode(String? nodeId) {
    if (selectedNodeId == nodeId && selectedEdgeId == null) return;
    selectedNodeId = nodeId;
    selectedEdgeId = null;
    notifyListeners();
  }

  void selectEdge(String? edgeId) {
    if (selectedEdgeId == edgeId) return;
    selectedEdgeId = edgeId;
    notifyListeners();
  }

  void setNeighborsOnly(bool value) {
    if (neighborsOnly == value) return;
    neighborsOnly = value;
    notifyListeners();
  }

  void rearrange() {
    layoutRevision++;
    notifyListeners();
  }

  void clearSelection() {
    if (selectedNodeId == null && selectedEdgeId == null) return;
    selectedNodeId = null;
    selectedEdgeId = null;
    notifyListeners();
  }

  void resetToGlobalPreview() {
    if (selectedNodeId == null && selectedEdgeId == null && !neighborsOnly) {
      return;
    }
    selectedNodeId = null;
    selectedEdgeId = null;
    neighborsOnly = false;
    notifyListeners();
  }

  void zoomBy(double factor, Size viewportSize) {
    final current = transformationController.value;
    final currentScale = current.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.25, 3.0);
    final ratio = targetScale / currentScale;
    final center = Offset(viewportSize.width / 2, viewportSize.height / 2);
    transformationController.value = Matrix4.identity()
      ..setEntry(0, 0, ratio)
      ..setEntry(1, 1, ratio)
      ..setEntry(2, 2, ratio)
      ..setTranslationRaw(center.dx * (1 - ratio), center.dy * (1 - ratio), 0)
      ..multiply(current);
  }

  void resetZoom() {
    transformationController.value = Matrix4.identity();
  }

  void fitCanvas(Size viewportSize, Size canvasSize) {
    if (viewportSize.isEmpty || canvasSize.isEmpty) return;
    final scale = math
        .min(
          viewportSize.width / canvasSize.width,
          viewportSize.height / canvasSize.height,
        )
        .clamp(0.25, 1.0);
    final dx = (viewportSize.width - canvasSize.width * scale) / 2;
    final dy = (viewportSize.height - canvasSize.height * scale) / 2;
    transformationController.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, scale)
      ..setTranslationRaw(dx, dy, 0);
  }

  Set<String> visibleNodeIds(CharacterRelationshipGraphData graph) {
    final selected = selectedNodeId;
    if (!neighborsOnly || selected == null) {
      return graph.nodes.map((node) => node.id).toSet();
    }
    final ids = <String>{selected};
    for (final edge in graph.edges) {
      if (edge.sourceCharacterId == selected) ids.add(edge.targetNodeId);
      if (edge.targetNodeId == selected) ids.add(edge.sourceCharacterId);
    }
    return ids;
  }

  @override
  void dispose() {
    transformationController.dispose();
    super.dispose();
  }
}
