import "../models/character_data.dart";
import "character_relationship_operations.dart";
import "character_relationship_resolver.dart";

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
  final int relationshipIndex;
  final CharacterRelationshipResolutionKind resolutionKind;
  final String? reverseEdgeId;
  final int? reverseRelationshipIndex;
  final String? reverseRawTargetPerson;

  const CharacterRelationshipGraphEdge({
    required this.id,
    required this.sourceCharacterId,
    required this.targetNodeId,
    required this.rawTargetPerson,
    required this.description,
    required this.relationshipIndex,
    required this.resolutionKind,
    this.reverseEdgeId,
    this.reverseRelationshipIndex,
    this.reverseRawTargetPerson,
  });

  bool get isResolved =>
      resolutionKind == CharacterRelationshipResolutionKind.resolved;

  bool get isBidirectional => reverseEdgeId != null;
}

class CharacterRelationshipGraphData {
  final List<CharacterRelationshipGraphNode> nodes;
  final List<CharacterRelationshipGraphEdge> edges;

  const CharacterRelationshipGraphData({
    required this.nodes,
    required this.edges,
  });

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
    Map<String, CharacterEntryData> characters,
  ) {
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
    final directionalEdges = <CharacterRelationshipGraphEdge>[];

    for (final source in characters.entries) {
      final relationships = mergeDuplicateCharacterRelationships(
        source.value.relationships,
      );
      for (var index = 0; index < relationships.length; index++) {
        final relationship = relationships[index];
        final resolution = resolver.resolve(relationship.person);
        final targetId =
            resolution.characterId ??
            _unresolvedNodeId(relationship.person, resolution.kind);
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
        directionalEdges.add(
          CharacterRelationshipGraphEdge(
            id: "${source.key}::$index::$targetId",
            sourceCharacterId: source.key,
            targetNodeId: targetId,
            rawTargetPerson: relationship.person,
            description: relationship.relationship.trim(),
            relationshipIndex: index,
            resolutionKind: resolution.kind,
          ),
        );
      }
    }

    nodes.addAll(unresolvedNodes.values);
    final edges = _mergeMatchingOppositeEdges(directionalEdges);
    return CharacterRelationshipGraphData(nodes: nodes, edges: edges);
  }

  List<CharacterRelationshipGraphEdge> _mergeMatchingOppositeEdges(
    List<CharacterRelationshipGraphEdge> directionalEdges,
  ) {
    final merged = <CharacterRelationshipGraphEdge>[];
    final consumedIds = <String>{};
    for (final edge in directionalEdges) {
      if (consumedIds.contains(edge.id)) continue;
      CharacterRelationshipGraphEdge? reverse;
      if (edge.isResolved && edge.sourceCharacterId != edge.targetNodeId) {
        for (final candidate in directionalEdges) {
          if (candidate.id == edge.id || consumedIds.contains(candidate.id)) {
            continue;
          }
          if (candidate.isResolved &&
              candidate.sourceCharacterId == edge.targetNodeId &&
              candidate.targetNodeId == edge.sourceCharacterId &&
              candidate.description == edge.description) {
            reverse = candidate;
            break;
          }
        }
      }

      consumedIds.add(edge.id);
      if (reverse == null) {
        merged.add(edge);
        continue;
      }
      consumedIds.add(reverse.id);
      merged.add(
        CharacterRelationshipGraphEdge(
          id: "${edge.id}<->${reverse.id}",
          sourceCharacterId: edge.sourceCharacterId,
          targetNodeId: edge.targetNodeId,
          rawTargetPerson: edge.rawTargetPerson,
          description: edge.description,
          relationshipIndex: edge.relationshipIndex,
          resolutionKind: edge.resolutionKind,
          reverseEdgeId: reverse.id,
          reverseRelationshipIndex: reverse.relationshipIndex,
          reverseRawTargetPerson: reverse.rawTargetPerson,
        ),
      );
    }
    return merged;
  }

  String _unresolvedNodeId(
    String person,
    CharacterRelationshipResolutionKind kind,
  ) {
    final normalized = person.trim().toLowerCase();
    return "unresolved:${kind.name}:${Uri.encodeComponent(normalized)}";
  }
}
