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

import "../models/character_data.dart";
import "character_relationship_operations.dart";
import "character_relationship_resolver.dart";

enum CharacterRelationshipDisplayMode { external, internal, both }

enum CharacterRelationshipLayer { external, internal }

/// A snapshot of a source row. Visual merging never changes this reference.
class CharacterRelationshipSource {
  final String characterId;
  final int index;
  final CharacterRelationship value;
  const CharacterRelationshipSource(this.characterId, this.index, this.value);
}

class CharacterRelationshipGraphNode {
  final String id;
  final String label;
  final CharacterEntryData? character;
  final String? unresolvedPerson;
  final CharacterRelationshipResolutionKind? unresolvedKind;
  const CharacterRelationshipGraphNode({
    required this.id,
    required this.label,
    this.character,
    this.unresolvedPerson,
    this.unresolvedKind,
  });
  bool get isUnresolved => character == null;
}

class CharacterRelationshipGraphEdge {
  final String id;
  final String sourceCharacterId;
  final String targetNodeId;
  final String rawTargetPerson;
  final String description;
  final String externalRelationship;
  final String internalRelationship;
  final int relationshipIndex;
  final CharacterRelationshipResolutionKind resolutionKind;
  final CharacterRelationshipLayer layer;
  final List<CharacterRelationshipSource> sources;
  final List<CharacterRelationshipSource> reverseSources;
  final String? reverseEdgeId;
  final int? reverseRelationshipIndex;
  final String? reverseRawTargetPerson;
  const CharacterRelationshipGraphEdge({
    required this.id,
    required this.sourceCharacterId,
    required this.targetNodeId,
    required this.rawTargetPerson,
    required this.description,
    this.externalRelationship = "",
    this.internalRelationship = "",
    required this.relationshipIndex,
    required this.resolutionKind,
    this.layer = CharacterRelationshipLayer.external,
    this.sources = const [],
    this.reverseSources = const [],
    this.reverseEdgeId,
    this.reverseRelationshipIndex,
    this.reverseRawTargetPerson,
  });
  bool get isResolved =>
      resolutionKind == CharacterRelationshipResolutionKind.resolved;
  bool get isBidirectional => reverseEdgeId != null;
  String get layerLabel =>
      layer == CharacterRelationshipLayer.external ? "外在" : "內在";
  String get canonicalSource => sourceCharacterId.compareTo(targetNodeId) <= 0
      ? sourceCharacterId
      : targetNodeId;
  String get canonicalTarget => sourceCharacterId.compareTo(targetNodeId) <= 0
      ? targetNodeId
      : sourceCharacterId;
  int get lane =>
      (sourceCharacterId == canonicalSource ? 0 : 2) +
      (layer == CharacterRelationshipLayer.internal ? 1 : 0);
  bool samePair(CharacterRelationshipGraphEdge other) =>
      canonicalSource == other.canonicalSource &&
      canonicalTarget == other.canonicalTarget;
}

class CharacterRelationshipGraphData {
  final List<CharacterRelationshipGraphNode> nodes;
  final List<CharacterRelationshipGraphEdge> edges;

  /// Unfiltered directional channels provide a stable topology for layout.
  final List<CharacterRelationshipGraphEdge> topologyEdges;
  const CharacterRelationshipGraphData({
    required this.nodes,
    required this.edges,
    List<CharacterRelationshipGraphEdge>? topologyEdges,
  }) : topologyEdges = topologyEdges ?? edges;
  CharacterRelationshipGraphNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  CharacterRelationshipGraphEdge? edgeById(String id) {
    for (final edge in edges) {
      if (edge.id == id) return edge;
    }
    return null;
  }
}

class CharacterRelationshipGraphMapper {
  const CharacterRelationshipGraphMapper();
  CharacterRelationshipGraphData map(
    Map<String, CharacterEntryData> characters, {
    CharacterRelationshipDisplayMode displayMode =
        CharacterRelationshipDisplayMode.external,
    bool mergeOpposite = true,
  }) {
    final resolver = CharacterRelationshipResolver(characters);
    final nodes = <CharacterRelationshipGraphNode>[
      for (final entry in characters.entries)
        CharacterRelationshipGraphNode(
          id: entry.key,
          label: CharacterRelationshipResolver.displayLabel(
            entry.key,
            characters,
          ),
          character: entry.value,
        ),
    ];
    final unresolvedNodes = <String, CharacterRelationshipGraphNode>{};
    final directional = <CharacterRelationshipGraphEdge>[];
    for (final source in characters.entries) {
      // Group duplicate rows for presentation, retaining every actual source index.
      final groups = <String, List<CharacterRelationshipSource>>{};
      for (var i = 0; i < source.value.relationships.length; i++) {
        final row = source.value.relationships[i];
        final resolved = resolver.resolve(row.person);
        final key = row.person.trim().isEmpty
            ? "empty:$i"
            : resolved.isResolved
            ? "resolved:${resolved.characterId}"
            : row.person.trim().toLowerCase();
        groups
            .putIfAbsent(key, () => [])
            .add(CharacterRelationshipSource(source.key, i, row));
      }
      for (final refs in groups.values) {
        final relationship = refs.first.value.copyWith(
          relationship: refs.fold<String>(
            "",
            (text, r) =>
                appendRelationshipDescription(text, r.value.relationship),
          ),
          internalRelationship: refs.fold<String>(
            "",
            (text, r) => appendRelationshipDescription(
              text,
              r.value.internalRelationship,
            ),
          ),
        );
        final resolution = resolver.resolve(relationship.person);
        final targetId =
            resolution.characterId ??
            "unresolved:${resolution.kind.name}:${Uri.encodeComponent(relationship.person.trim().toLowerCase())}";
        if (!resolution.isResolved) {
          unresolvedNodes.putIfAbsent(
            targetId,
            () => CharacterRelationshipGraphNode(
              id: targetId,
              label:
                  resolution.kind ==
                      CharacterRelationshipResolutionKind.ambiguous
                  ? "名稱不明確：${relationship.person.trim()}"
                  : "未連結：${relationship.person.trim().isEmpty ? '未命名' : relationship.person.trim()}",
              unresolvedPerson: relationship.person,
              unresolvedKind: resolution.kind,
            ),
          );
        }
        for (final layer in CharacterRelationshipLayer.values) {
          final description = layer == CharacterRelationshipLayer.external
              ? relationship.relationship.trim()
              : relationship.internalRelationship.trim();
          if (description.isEmpty) continue;
          directional.add(
            CharacterRelationshipGraphEdge(
              id: "${source.key}::${refs.first.index}::$targetId::${layer.name}",
              sourceCharacterId: source.key,
              targetNodeId: targetId,
              rawTargetPerson: relationship.person,
              description: description,
              externalRelationship: relationship.relationship.trim(),
              internalRelationship: relationship.internalRelationship.trim(),
              relationshipIndex: refs.first.index,
              resolutionKind: resolution.kind,
              layer: layer,
              sources: List.unmodifiable(refs),
            ),
          );
        }
      }
    }
    nodes.addAll(unresolvedNodes.values);
    directional.sort((a, b) => a.id.compareTo(b.id));
    final visible = directional
        .where(
          (edge) =>
              displayMode == CharacterRelationshipDisplayMode.both ||
              (displayMode == CharacterRelationshipDisplayMode.external &&
                  edge.layer == CharacterRelationshipLayer.external) ||
              (displayMode == CharacterRelationshipDisplayMode.internal &&
                  edge.layer == CharacterRelationshipLayer.internal),
        )
        .toList();
    final edges = <CharacterRelationshipGraphEdge>[];
    final consumed = <String>{};
    final byDirection = <String, CharacterRelationshipGraphEdge>{
      for (final edge in visible)
        "${edge.sourceCharacterId}::${edge.targetNodeId}::${edge.layer.name}":
            edge,
    };
    for (final edge in visible) {
      if (!consumed.add(edge.id)) continue;
      final reverse =
          mergeOpposite &&
              edge.isResolved &&
              edge.sourceCharacterId != edge.targetNodeId
          ? byDirection["${edge.targetNodeId}::${edge.sourceCharacterId}::${edge.layer.name}"]
          : null;
      if (reverse == null ||
          reverse.description != edge.description ||
          consumed.contains(reverse.id)) {
        edges.add(edge);
      } else {
        consumed.add(reverse.id);
        edges.add(
          CharacterRelationshipGraphEdge(
            id: "${edge.id}<->${reverse.id}",
            sourceCharacterId: edge.sourceCharacterId,
            targetNodeId: edge.targetNodeId,
            rawTargetPerson: edge.rawTargetPerson,
            description: edge.description,
            externalRelationship: edge.externalRelationship,
            internalRelationship: edge.internalRelationship,
            relationshipIndex: edge.relationshipIndex,
            resolutionKind: edge.resolutionKind,
            layer: edge.layer,
            sources: edge.sources,
            reverseSources: reverse.sources,
            reverseEdgeId: reverse.id,
            reverseRelationshipIndex: reverse.relationshipIndex,
            reverseRawTargetPerson: reverse.rawTargetPerson,
          ),
        );
      }
    }
    return CharacterRelationshipGraphData(
      nodes: nodes,
      edges: edges,
      topologyEdges: directional,
    );
  }
}
