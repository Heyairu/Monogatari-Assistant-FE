import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_controller.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_layout.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_mapper.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_mutations.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_routing.dart";

const mapper = CharacterRelationshipGraphMapper();
const nodeSize = Size.square(104);

Map<String, CharacterEntryData> pair({bool matchingInternal = false}) => {
  "a": const CharacterEntryData(
    characterId: "a",
    displayName: "A",
    relationships: [
      CharacterRelationship(
        person: "B",
        relationship: "同事",
        internalRelationship: "信任",
      ),
    ],
  ),
  "b": CharacterEntryData(
    characterId: "b",
    displayName: "B",
    relationships: [
      CharacterRelationship(
        person: "A",
        relationship: "同事",
        internalRelationship: matchingInternal ? "信任" : "嫉妒",
      ),
    ],
  ),
};

Map<String, EdgeVisualLayout> route(
  CharacterRelationshipGraphData graph,
  Map<String, Offset> positions, {
  Set<String> labeled = const {},
}) => routeCharacterEdges(
  graph.edges,
  positions,
  const Size(1200, 900),
  nodeSize: nodeSize,
  labelSizes: {for (final e in graph.edges) e.id: const Size(100, 36)},
  labeledEdgeIds: labeled,
);

void main() {
  test("focus labels reuse obstacle routing geometry", () {
    final graph = mapper.map(pair());
    final positions = {
      "a": const Offset(100, 300),
      "b": const Offset(800, 300),
    };
    final geometries = routeCharacterEdgeGeometries(
      graph.edges,
      positions,
      const Size(1200, 900),
      nodeSize: nodeSize,
    );
    for (final focused in [<String>{}, graph.edges.map((e) => e.id).toSet()]) {
      final routes = placeCharacterEdgeLabels(
        graph.edges,
        geometries,
        positions,
        const Size(1200, 900),
        nodeSize: nodeSize,
        labelSizes: {for (final e in graph.edges) e.id: const Size(100, 36)},
        labeledEdgeIds: focused,
      );
      for (final edge in graph.edges) {
        expect(
          identical(routes[edge.id]!.geometry, geometries[edge.id]),
          isTrue,
        );
      }
    }
  });

  test("clusters compact isolated nodes and separate unresolved targets", () {
    final characters = pair();
    for (var i = 0; i < 16; i++) {
      characters["isolated-$i"] = CharacterEntryData(
        characterId: "isolated-$i",
        displayName: "Isolated $i",
      );
    }
    characters["a"] = characters["a"]!.copyWith(
      relationships: [
        ...characters["a"]!.relationships,
        const CharacterRelationship(person: "Unknown", relationship: "尋找"),
      ],
    );
    final graph = mapper.map(characters);
    final layout = CharacterGraphLayoutSession().resolve(
      graph,
      CharacterGraphLayoutMode.clusters,
      nodeSize,
    );
    final isolated = characters.keys.where((id) => id.startsWith("isolated-"));
    final rows = isolated.map((id) => layout.positions[id]!.dy).toSet();
    expect(rows.length, 2);
    final unresolved = graph.nodes.singleWhere((node) => node.isUnresolved);
    for (final node in graph.nodes.where((node) => !node.isUnresolved)) {
      expect(
        layout.positions[unresolved.id]!.dy,
        greaterThan(layout.positions[node.id]!.dy + nodeSize.height),
      );
    }
    final again = CharacterGraphLayoutSession().resolve(
      mapper.map(Map.fromEntries(characters.entries.toList().reversed)),
      CharacterGraphLayoutMode.clusters,
      nodeSize,
    );
    expect(again.positions, layout.positions);
  });

  test("cached mode avoids a pinned anchor moved from another mode", () {
    final graph = mapper.map(pair());
    final session = CharacterGraphLayoutSession();
    final roles = session.resolve(
      graph,
      CharacterGraphLayoutMode.roles,
      nodeSize,
    );
    session.togglePin("a");
    session.resolve(graph, CharacterGraphLayoutMode.clusters, nodeSize);
    session.move(CharacterGraphLayoutMode.clusters, "a", roles.positions["b"]!);
    final restored = session.resolve(
      graph,
      CharacterGraphLayoutMode.roles,
      nodeSize,
    );
    expect(restored.positions["a"], roles.positions["b"]);
    expect(
      (restored.positions["a"]! & nodeSize).overlaps(
        restored.positions["b"]! & nodeSize,
      ),
      isFalse,
    );
  });
  test(
    "name and NanoID references resolve into the same four-channel pair",
    () {
      final source = pair();
      source["b"] = source["b"]!.copyWith(legacyFields: {"nanoId": "BOB00001"});
      source["a"] = source["a"]!.copyWith(
        relationships: const [
          CharacterRelationship(
            person: "B",
            relationship: "同事",
            internalRelationship: "信任",
          ),
          CharacterRelationship(
            person: "B (BOB00001)",
            relationship: "好友",
            internalRelationship: "期待",
          ),
        ],
      );
      final graph = mapper.map(
        source,
        displayMode: CharacterRelationshipDisplayMode.both,
        mergeOpposite: false,
      );
      expect(graph.edges, hasLength(4));
      final forward = graph.edges
          .where((e) => e.sourceCharacterId == "a")
          .toList();
      expect(forward.every((e) => e.sources.length == 2), isTrue);
      expect(
        forward.map((e) => e.description),
        containsAll(["同事、好友", "信任、期待"]),
      );
    },
  );
  test("four independent channels, layer-specific merge, empty layers", () {
    final source = pair();
    final split = mapper.map(
      source,
      displayMode: CharacterRelationshipDisplayMode.both,
      mergeOpposite: false,
    );
    expect(split.edges, hasLength(4));
    expect(split.edges.map((e) => e.lane).toSet(), {0, 1, 2, 3});
    final merged = mapper.map(
      source,
      displayMode: CharacterRelationshipDisplayMode.both,
    );
    expect(merged.edges, hasLength(3));
    final mergedRoutes = route(merged, {
      "a": const Offset(100, 350),
      "b": const Offset(900, 350),
    });
    expect(
      mergedRoutes.values.map((r) => r.geometry.control).toSet(),
      hasLength(3),
    );
    expect(
      merged.edges.where((e) => e.isBidirectional).single.layer,
      CharacterRelationshipLayer.external,
    );
    expect(
      mapper
          .map(
            pair(matchingInternal: true),
            displayMode: CharacterRelationshipDisplayMode.both,
          )
          .edges,
      hasLength(2),
    );
    final empty = {
      "a": const CharacterEntryData(
        characterId: "a",
        displayName: "A",
        relationships: [CharacterRelationship(person: "Ghost")],
      ),
    };
    final graph = mapper.map(empty);
    expect(graph.edges, isEmpty);
    expect(graph.nodes.where((n) => n.isUnresolved), hasLength(1));
    expect(empty["a"]!.relationships, hasLength(1));
  });

  test(
    "editing merged external direction preserves both feelings and reverse row",
    () {
      final source = pair();
      final edge = mapper.map(source).edges.single;
      final next = updateCharacterRelationshipChannel(
        source,
        sources: edge.sources,
        layer: edge.layer,
        description: "朋友",
      )!;
      expect(next["a"]!.relationships.single.relationship, "朋友");
      expect(next["a"]!.relationships.single.internalRelationship, "信任");
      expect(next["b"], source["b"]);
      final deleted = updateCharacterRelationshipChannel(
        source,
        sources: edge.reverseSources,
        layer: edge.layer,
        description: "",
      )!;
      expect(deleted["b"]!.relationships.single.relationship, isEmpty);
      expect(deleted["b"]!.relationships.single.internalRelationship, "嫉妒");
      expect(deleted["a"], source["a"]);
      final direction = updateCharacterRelationshipChannel(
        source,
        sources: edge.sources,
        layer: edge.layer,
        description: "",
        deleteDirection: true,
      )!;
      expect(direction["a"]!.relationships, isEmpty);
      expect(direction["b"], source["b"]);
    },
  );

  test(
    "duplicate presentation retains original indices and rejects stale rows atomically",
    () {
      final source = pair();
      source["a"] = source["a"]!.copyWith(
        relationships: const [
          CharacterRelationship(person: "Other", relationship: "其他"),
          CharacterRelationship(
            person: "B",
            relationship: "同事",
            internalRelationship: "信任",
          ),
          CharacterRelationship(
            person: "b",
            relationship: "好友",
            internalRelationship: "期待",
          ),
        ],
      );
      final edge = mapper
          .map(source, mergeOpposite: false)
          .edges
          .firstWhere(
            (e) => e.targetNodeId == "b" && e.sourceCharacterId == "a",
          );
      expect(edge.sources.map((r) => r.index), [1, 2]);
      final next = updateCharacterRelationshipChannel(
        source,
        sources: edge.sources,
        layer: edge.layer,
        description: "家人",
      )!;
      expect(next["a"]!.relationships[0], source["a"]!.relationships[0]);
      expect(next["a"]!.relationships[1].relationship, "家人");
      expect(next["a"]!.relationships[2].relationship, isEmpty);
      expect(next["a"]!.relationships[2].internalRelationship, "期待");
      final stale = Map<String, CharacterEntryData>.of(source);
      stale["a"] = stale["a"]!.copyWith(
        relationships: source["a"]!.relationships.reversed.toList(),
      );
      expect(
        updateCharacterRelationshipChannel(
          stale,
          sources: edge.sources,
          layer: edge.layer,
          description: "錯誤",
        ),
        isNull,
      );
    },
  );

  test(
    "route lanes remain distinct and unchanged by filtering or label focus",
    () {
      final source = pair();
      final full = mapper.map(
        source,
        displayMode: CharacterRelationshipDisplayMode.both,
        mergeOpposite: false,
      );
      const positions = {
        "a": Offset(180, 350),
        "b": Offset(880, 350),
        "blocker": Offset(520, 350),
      };
      final routes = route(full, positions);
      expect(
        routes.values.map((r) => r.geometry.control.dy).toSet(),
        hasLength(4),
      );
      final filtered = mapper.map(source, mergeOpposite: false);
      final external = route(filtered, positions);
      final focused = route(
        full,
        positions,
        labeled: full.edges.map((e) => e.id).toSet(),
      );
      for (final edge in filtered.edges) {
        expect(
          external[edge.id]!.geometry.control,
          routes[edge.id]!.geometry.control,
        );
        expect(
          focused[edge.id]!.geometry.control,
          routes[edge.id]!.geometry.control,
        );
        final g = routes[edge.id]!.geometry;
        for (var i = 1; i < 100; i++) {
          expect(
            (positions["blocker"]! & nodeSize).contains(
              quadraticPoint(g.start, g.control, g.end, i / 100),
            ),
            isFalse,
          );
        }
      }
    },
  );

  test("self relationships use separate nonzero loops", () {
    final source = {
      "a": const CharacterEntryData(
        characterId: "a",
        displayName: "A",
        relationships: [
          CharacterRelationship(
            person: "A",
            relationship: "自己",
            internalRelationship: "自信",
          ),
        ],
      ),
    };
    final graph = mapper.map(
      source,
      displayMode: CharacterRelationshipDisplayMode.both,
    );
    final routes = route(graph, {"a": const Offset(400, 400)});
    expect(
      routes.values.first.geometry.start,
      isNot(routes.values.first.geometry.end),
    );
    expect(routes.values.map((r) => r.geometry.control).toSet(), hasLength(2));
    expect(graph.edges.every((e) => !e.isBidirectional), isTrue);
    final top = route(graph, {"a": const Offset(24, 24)});
    for (final layout in top.values) {
      final g = layout.geometry;
      for (var i = 0; i <= 100; i++) {
        final point = quadraticPoint(g.start, g.control, g.end, i / 100);
        expect(point.dy, greaterThanOrEqualTo(8));
      }
    }
  });

  for (final mode in CharacterGraphLayoutMode.values) {
    test(
      "${mode.name}: crowded same-organization roles never overlap, deterministic with enlarged text",
      () {
        final source = {
          for (var i = 0; i < 70; i++)
            "id-$i": CharacterEntryData(
              characterId: "id-$i",
              displayName: "角色 $i",
              characterType: i % 5 == 0 ? "主角" : "重要配角",
              organizations: const [CharacterProfileTableEntry(name: "同盟")],
              relationships: i == 0
                  ? const []
                  : [
                      CharacterRelationship(
                        person: "角色 0",
                        relationship: "同伴",
                        internalRelationship: "信任",
                      ),
                    ],
            ),
        };
        final graph = mapper.map(
          source,
          displayMode: CharacterRelationshipDisplayMode.both,
        );
        const size = Size.square(208);
        final result = CharacterGraphLayoutSession().resolve(graph, mode, size);
        final again = CharacterGraphLayoutSession().resolve(graph, mode, size);
        expect(result.positions, again.positions);
        final rects = result.positions.values.map((p) => p & size).toList();
        for (var i = 0; i < rects.length; i++) {
          expect(rects[i].left, greaterThanOrEqualTo(24));
          expect(rects[i].right, lessThan(result.canvasSize.width));
          for (var j = i + 1; j < rects.length; j++) {
            expect(
              rects[i].inflate(19).overlaps(rects[j].inflate(19)),
              isFalse,
              reason: "$i overlaps $j",
            );
          }
        }
      },
    );
  }

  test(
    "positions survive filter, merging, insertion and deletion; pins survive modes and rearrange",
    () {
      final controller = CharacterRelationshipGraphController();
      addTearDown(controller.dispose);
      final session = controller.layoutSession;
      final source = pair();
      final initial = session.resolve(
        mapper.map(source),
        controller.layoutMode,
        nodeSize,
      );
      session.move(controller.layoutMode, "a", const Offset(300, 300));
      session.togglePin("a");
      controller.selectNode("a");
      controller.setMergeOpposite(false);
      final filtered = session.resolve(
        mapper.map(
          source,
          displayMode: CharacterRelationshipDisplayMode.internal,
        ),
        controller.layoutMode,
        nodeSize,
      );
      expect(filtered.positions["a"], const Offset(300, 300));
      expect(filtered.positions["b"], initial.positions["b"]);
      source["c"] = const CharacterEntryData(
        characterId: "c",
        displayName: "C",
      );
      final inserted = session.resolve(
        mapper.map(source),
        controller.layoutMode,
        nodeSize,
      );
      expect(inserted.positions["b"], initial.positions["b"]);
      controller.rearrange();
      final rearranged = session.resolve(
        mapper.map(source),
        controller.layoutMode,
        nodeSize,
        layoutRevision: controller.layoutRevision,
      );
      expect(rearranged.positions["a"], const Offset(300, 300));
      controller.setLayoutMode(CharacterGraphLayoutMode.clusters);
      expect(
        session
            .resolve(mapper.map(source), controller.layoutMode, nodeSize)
            .positions["a"],
        const Offset(300, 300),
      );
      session.move(controller.layoutMode, "a", const Offset(500, 420));
      controller.setLayoutMode(CharacterGraphLayoutMode.roles);
      expect(
        session
            .resolve(mapper.map(source), controller.layoutMode, nodeSize)
            .positions["a"],
        const Offset(500, 420),
      );
      source.remove("c");
      expect(
        session
            .resolve(mapper.map(source), controller.layoutMode, nodeSize)
            .positions
            .containsKey("c"),
        isFalse,
      );
      controller.resetSession();
      expect(session.pinned, isEmpty);
      expect(controller.selectedNodeId, isNull);
      expect(controller.layoutMode, CharacterGraphLayoutMode.roles);
    },
  );

  test(
    "cluster distances use character pairs rather than rendered channel counts",
    () {
      final source = pair();
      final external = mapper.map(source);
      final both = mapper.map(
        source,
        displayMode: CharacterRelationshipDisplayMode.both,
        mergeOpposite: false,
      );
      expect(
        CharacterGraphLayoutSession()
            .resolve(external, CharacterGraphLayoutMode.clusters, nodeSize)
            .positions,
        CharacterGraphLayoutSession()
            .resolve(both, CharacterGraphLayoutMode.clusters, nodeSize)
            .positions,
      );
    },
  );
}
