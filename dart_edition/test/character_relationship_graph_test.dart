import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_controller.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_mapper.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_view.dart";
import "package:monogatari_assistant/modules/character_relationship_operations.dart";
import "package:monogatari_assistant/modules/character_relationship_resolver.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:monogatari_assistant/ui_library/forms.dart";

void main() {
  CharacterEntryData character(
    String id,
    String name,
    String nanoId, {
    List<CharacterRelationship> relationships = const [],
    String characterType = defaultCharacterType,
    List<CharacterProfileTableEntry> organizations = const [],
  }) {
    return CharacterEntryData.withName(name).copyWith(
      characterId: id,
      displayName: name,
      legacyFields: {"nanoId": nanoId},
      relationships: relationships,
      characterType: characterType,
      organizations: organizations,
    );
  }

  group("CharacterRelationshipResolver", () {
    test("matches unique display names ignoring whitespace and case", () {
      final characters = {"alice": character("alice", "Alice", "ALICE001")};

      final result = CharacterRelationshipResolver(
        characters,
      ).resolve("  aLiCe  ");

      expect(result.kind, CharacterRelationshipResolutionKind.resolved);
      expect(result.characterId, "alice");
    });

    test("does not choose arbitrarily when display names are duplicated", () {
      final characters = {
        "first": character("first", "小明", "MING0001"),
        "second": character("second", "小明", "MING0002"),
      };
      final resolver = CharacterRelationshipResolver(characters);

      expect(
        resolver.resolve("小明").kind,
        CharacterRelationshipResolutionKind.ambiguous,
      );
      expect(resolver.resolve("小明 (MING0002)").characterId, "second");
      expect(
        CharacterRelationshipResolver.displayLabel("first", characters),
        "小明 (MING0001)",
      );
    });
  });

  group("CharacterRelationshipGraphMapper", () {
    test("keeps unresolved relationships as visible dangling nodes", () {
      final characters = {
        "alice": character(
          "alice",
          "Alice",
          "ALICE001",
          relationships: const [
            CharacterRelationship(person: "Ghost", relationship: "尋找中"),
          ],
        ),
      };

      final graph = const CharacterRelationshipGraphMapper().map(characters);

      expect(graph.edges, hasLength(1));
      expect(graph.edges.single.isResolved, isFalse);
      expect(graph.edges.single.rawTargetPerson, "Ghost");
      expect(graph.nodes.where((node) => node.isUnresolved), hasLength(1));
      expect(
        graph.nodeById(graph.edges.single.targetNodeId)?.label,
        "未連結：Ghost",
      );
    });

    test("preserves opposite directions as separate edges", () {
      final characters = {
        "alice": character(
          "alice",
          "Alice",
          "ALICE001",
          relationships: const [
            CharacterRelationship(person: "Bob", relationship: "信任"),
          ],
        ),
        "bob": character(
          "bob",
          "Bob",
          "BOB00001",
          relationships: const [
            CharacterRelationship(person: "Alice", relationship: "競爭"),
          ],
        ),
      };

      final graph = const CharacterRelationshipGraphMapper().map(characters);

      expect(graph.edges, hasLength(2));
      expect(
        graph.edges.map(
          (edge) => "${edge.sourceCharacterId}->${edge.targetNodeId}",
        ),
        containsAll(["alice->bob", "bob->alice"]),
      );
    });

    test(
      "merges matching opposite relationships into one bidirectional edge",
      () {
        final characters = {
          "alice": character(
            "alice",
            "Alice",
            "ALICE001",
            relationships: const [
              CharacterRelationship(person: "Bob", relationship: "朋友"),
            ],
          ),
          "bob": character(
            "bob",
            "Bob",
            "BOB00001",
            relationships: const [
              CharacterRelationship(person: "Alice", relationship: "朋友"),
            ],
          ),
        };

        final graph = const CharacterRelationshipGraphMapper().map(characters);

        expect(graph.edges, hasLength(1));
        expect(graph.edges.single.isBidirectional, isTrue);
        expect(graph.edges.single.reverseRelationshipIndex, 0);
      },
    );
  });

  test("graph controller defaults to a global preview", () {
    final controller = CharacterRelationshipGraphController();
    addTearDown(controller.dispose);
    final graph = const CharacterRelationshipGraphMapper().map({
      "alice": character(
        "alice",
        "Alice",
        "ALICE001",
        relationships: const [
          CharacterRelationship(person: "Bob", relationship: "朋友"),
        ],
      ),
      "bob": character("bob", "Bob", "BOB00001"),
      "carol": character("carol", "Carol", "CAROL001"),
    });

    expect(controller.neighborsOnly, isFalse);
    expect(
      controller.visibleNodeIds(graph),
      containsAll(<String>{"alice", "bob", "carol"}),
    );

    controller
      ..selectNode("alice")
      ..setNeighborsOnly(true)
      ..selectEdge(graph.edges.single.id)
      ..resetToGlobalPreview();

    expect(controller.selectedNodeId, isNull);
    expect(controller.selectedEdgeId, isNull);
    expect(controller.neighborsOnly, isFalse);
  });

  group("relationship editing rules", () {
    test("merges duplicate people and de-duplicates descriptions", () {
      const source = [
        CharacterRelationship(person: " Bob ", relationship: "朋友"),
        CharacterRelationship(person: "bob", relationship: "朋友"),
        CharacterRelationship(person: "BOB", relationship: "同事"),
      ];

      final merged = mergeDuplicateCharacterRelationships(source);

      expect(merged, hasLength(1));
      expect(merged.single.person, "Bob");
      expect(merged.single.relationship, "朋友、同事");
    });

    test("upsert merges an edited row into an existing target", () {
      const source = [
        CharacterRelationship(person: "Alice", relationship: "朋友"),
        CharacterRelationship(person: "Bob", relationship: "同事"),
      ];

      final updated = upsertCharacterRelationship(
        relationships: source,
        person: "Alice",
        description: "家人",
        editingIndex: 1,
      );

      expect(updated, hasLength(1));
      expect(updated.single.person, "Alice");
      expect(updated.single.relationship, "朋友、家人");
    });
  });

  testWidgets(
    "graph places roles in rings and shows organizations in details",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const guild = CharacterProfileTableEntry(
        name: "冒險者公會",
        description: "成員",
      );
      const order = CharacterProfileTableEntry(
        name: "白銀騎士團",
        description: "團員",
      );
      container.read(characterDataProvider.notifier).setCharacterData({
        "support": character(
          "support",
          "重要配角",
          "SUPPORT1",
          characterType: "重要配角",
          organizations: const [guild, order],
        ),
        "secondary-support": character(
          "secondary-support",
          "次要配角",
          "SUPPORT2",
          characterType: "次要配角",
          organizations: const [guild, order],
        ),
        "hero": character(
          "hero",
          "故事主角",
          "HERO0001",
          characterType: "主角",
          organizations: const [guild],
        ),
        "main-villain": character(
          "main-villain",
          "主要反派角色",
          "VILLAIN1",
          characterType: "主要反派",
        ),
        "secondary-villain": character(
          "secondary-villain",
          "次要反派角色甲",
          "VILLAIN2",
          characterType: "次要反派",
        ),
        "secondary-villain-two": character(
          "secondary-villain-two",
          "次要反派角色乙",
          "VILLAIN3",
          characterType: "次要反派",
        ),
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CharacterRelationshipGraphView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final supportRect = tester.getRect(
        find.byKey(const ValueKey("relationship-node-support")),
      );
      final secondarySupportRect = tester.getRect(
        find.byKey(const ValueKey("relationship-node-secondary-support")),
      );
      final heroRect = tester.getRect(
        find.byKey(const ValueKey("relationship-node-hero")),
      );
      expect(heroRect.width, closeTo(heroRect.height, 0.01));
      final heroNode = find.byKey(const ValueKey("relationship-node-hero"));
      final heroIconRect = tester.getRect(
        find.descendant(
          of: heroNode,
          matching: find.byIcon(Icons.person_outline),
        ),
      );
      final heroNameRect = tester.getRect(
        find.descendant(of: heroNode, matching: find.text("故事主角")),
      );
      expect(heroIconRect.center.dy, lessThan(heroNameRect.center.dy));
      final mainVillainRect = tester.getRect(
        find.byKey(const ValueKey("relationship-node-main-villain")),
      );
      final secondaryVillainRect = tester.getRect(
        find.byKey(const ValueKey("relationship-node-secondary-villain")),
      );
      final secondaryVillainTwoRect = tester.getRect(
        find.byKey(const ValueKey("relationship-node-secondary-villain-two")),
      );

      expect(heroRect.center.dx, lessThan(mainVillainRect.center.dx));
      expect(
        (supportRect.center - heroRect.center).distance,
        lessThan((secondarySupportRect.center - heroRect.center).distance),
      );
      final secondaryVillainMidpoint = Offset(
        (secondaryVillainRect.center.dx + secondaryVillainTwoRect.center.dx) /
            2,
        (secondaryVillainRect.center.dy + secondaryVillainTwoRect.center.dy) /
            2,
      );
      expect(
        (secondaryVillainMidpoint - mainVillainRect.center).distance,
        lessThan(2),
      );

      expect(
        find.byKey(const ValueKey("relationship-organization-shape-冒險者公會")),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey("relationship-node-support")));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey("relationship-node-organization-chip-support-0"),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey("relationship-node-organization-chip-support-1"),
        ),
        findsOneWidget,
      );
      expect(find.text("所屬組織"), findsOneWidget);
      expect(find.text("冒險者公會"), findsOneWidget);
      expect(find.text("白銀騎士團"), findsOneWidget);
      expect(find.byTooltip("成員"), findsOneWidget);
      expect(find.byTooltip("團員"), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("same-organization nodes share a compact ring sector", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const guild = CharacterProfileTableEntry(name: "同盟", description: "成員");
    container.read(characterDataProvider.notifier).setCharacterData({
      "hero": character("hero", "Hero", "HERO0001", characterType: "主角"),
      "member-a": character(
        "member-a",
        "Member A",
        "MEMBERA1",
        characterType: "重要配角",
        organizations: const [guild],
      ),
      "member-b": character(
        "member-b",
        "Member B",
        "MEMBERB1",
        characterType: "重要配角",
        organizations: const [guild],
      ),
      "outsider": character(
        "outsider",
        "Outsider",
        "OUTSIDE1",
        characterType: "重要配角",
      ),
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CharacterRelationshipGraphView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Rect nodeRect(String id) =>
        tester.getRect(find.byKey(ValueKey("relationship-node-$id")));
    final memberA = nodeRect("member-a");
    final memberB = nodeRect("member-b");
    final outsider = nodeRect("outsider");
    final memberDistance = (memberA.center - memberB.center).distance;
    expect(
      memberDistance,
      lessThan(
        math.min(
          (memberA.center - outsider.center).distance,
          (memberB.center - outsider.center).distance,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey("relationship-organization-shape-同盟")),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey("relationship-node-member-a")));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey("relationship-node-organization-chip-member-a-0"),
      ),
      findsOneWidget,
    );
    expect(find.text("同盟"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "smaller organization sectors come first and outsiders stay apart",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const small = CharacterProfileTableEntry(name: "小組織", description: "成員");
      const large = CharacterProfileTableEntry(name: "大組織", description: "成員");
      container.read(characterDataProvider.notifier).setCharacterData({
        "hero": character("hero", "Hero", "HERO0001", characterType: "主角"),
        for (var index = 0; index < 2; index++)
          "small-$index": character(
            "small-$index",
            "Small $index",
            "SMALL00$index",
            characterType: "重要配角",
            organizations: const [small],
          ),
        for (var index = 0; index < 3; index++)
          "large-$index": character(
            "large-$index",
            "Large $index",
            "LARGE00$index",
            characterType: "重要配角",
            organizations: const [large],
          ),
        "outsider": character(
          "outsider",
          "Outsider",
          "OUTSIDE1",
          characterType: "重要配角",
        ),
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CharacterRelationshipGraphView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester
          .getRect(find.byKey(const ValueKey("relationship-node-hero")))
          .center;
      double phase(String id) {
        final nodeCenter = tester
            .getRect(find.byKey(ValueKey("relationship-node-$id")))
            .center;
        final angle = math.atan2(
          nodeCenter.dy - center.dy,
          nodeCenter.dx - center.dx,
        );
        return (angle + math.pi) % (2 * math.pi);
      }

      final smallPhases = [phase("small-0"), phase("small-1")];
      final largePhases = [
        phase("large-0"),
        phase("large-1"),
        phase("large-2"),
      ];
      final outsiderPhase = phase("outsider");
      expect(
        smallPhases.reduce(math.min),
        lessThan(largePhases.reduce(math.min)),
      );
      expect(largePhases.reduce(math.max), lessThan(outsiderPhase));

      final smallCenter =
          smallPhases.reduce((left, right) => left + right) /
          smallPhases.length;
      final outsiderDistance = math.min(
        (outsiderPhase - smallCenter).abs(),
        2 * math.pi - (outsiderPhase - smallCenter).abs(),
      );
      expect(outsiderDistance, greaterThan(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("relationship curves route around a blocking character", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const guild = CharacterProfileTableEntry(name: "同盟", description: "成員");
    container.read(characterDataProvider.notifier).setCharacterData({
      "hero": character(
        "hero",
        "Hero",
        "HERO0001",
        characterType: "主角",
        relationships: const [
          CharacterRelationship(person: "Target", relationship: "繞行"),
        ],
      ),
      "blocker": character(
        "blocker",
        "Blocker",
        "BLOCKER1",
        characterType: "重要配角",
        organizations: const [guild],
      ),
      "target": character(
        "target",
        "Target",
        "TARGET01",
        characterType: "次要配角",
        organizations: const [guild],
      ),
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CharacterRelationshipGraphView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final edgeLayer = find.byKey(const ValueKey("relationship-edge-layer"));
    final edgePainter = tester.widget<CustomPaint>(edgeLayer).painter!;
    final edgeBox = tester.renderObject<RenderBox>(edgeLayer);
    final blockerRect = tester.getRect(
      find.byKey(const ValueKey("relationship-node-blocker")),
    );
    for (var column = 1; column < 5; column++) {
      for (var row = 1; row < 5; row++) {
        final globalPoint = Offset(
          blockerRect.left + blockerRect.width * column / 5,
          blockerRect.top + blockerRect.height * row / 5,
        );
        expect(
          edgePainter.hitTest(edgeBox.globalToLocal(globalPoint)),
          isFalse,
        );
      }
    }

    final heroCenter = tester
        .getRect(find.byKey(const ValueKey("relationship-node-hero")))
        .center;
    final targetCenter = tester
        .getRect(find.byKey(const ValueKey("relationship-node-target")))
        .center;
    final labelCenter = tester
        .getRect(
          find.byKey(const ValueKey("relationship-edge-label-hero::0::target")),
        )
        .center;
    final directLine = targetCenter - heroCenter;
    final labelVector = labelCenter - heroCenter;
    final labelDistanceFromDirectLine =
        (directLine.dx * labelVector.dy - directLine.dy * labelVector.dx)
            .abs() /
        directLine.distance;
    expect(labelDistanceFromDirectLine, greaterThan(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets("graph renders and edits provider-backed relationships", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData({
      "alice": character(
        "alice",
        "Alice",
        "ALICE001",
        relationships: const [
          CharacterRelationship(person: "Bob", relationship: "信任"),
        ],
      ),
      "bob": character("bob", "Bob", "BOB00001"),
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CharacterRelationshipGraphView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Alice"), findsOneWidget);
    expect(find.text("Bob"), findsOneWidget);
    expect(find.text("信任"), findsOneWidget);
    final relationshipLabelRect = tester.getRect(
      find.byKey(const ValueKey("relationship-edge-label-alice::0::bob")),
    );
    expect(
      relationshipLabelRect.overlaps(
        tester.getRect(find.byKey(const ValueKey("relationship-node-alice"))),
      ),
      isFalse,
    );
    expect(
      relationshipLabelRect.overlaps(
        tester.getRect(find.byKey(const ValueKey("relationship-node-bob"))),
      ),
      isFalse,
    );

    final edgeInkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text("信任"), matching: find.byType(InkWell)).first,
    );
    edgeInkWell.onTap!();
    await tester.pumpAndSettle();
    expect(find.text("Alice → Bob"), findsOneWidget);

    final canvasRect = tester.getRect(
      find.byKey(const ValueKey("relationship-graph-canvas")),
    );
    await tester.tapAt(canvasRect.bottomLeft + const Offset(8, -8));
    await tester.pumpAndSettle();
    expect(find.text("Alice → Bob"), findsOneWidget);

    await tester.tap(find.text("編輯"));
    await tester.pumpAndSettle();
    expect(find.text("雙向關係"), findsNothing);
    final descriptionField = find.descendant(
      of: find.byKey(const ValueKey("relationship-description-field")),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(descriptionField, "摯友");
    await tester.tap(find.text("儲存"));
    await tester.pumpAndSettle();

    expect(
      container
          .read(characterDataProvider)["alice"]
          ?.relationships
          .single
          .relationship,
      "摯友",
    );
    expect(find.text("摯友"), findsOneWidget);
  });

  testWidgets("crowded relationship labels avoid nodes and each other", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData({
      "hero": character(
        "hero",
        "Hero",
        "HERO0001",
        characterType: "主角",
        relationships: const [
          CharacterRelationship(person: "Alpha", relationship: "盟友甲"),
          CharacterRelationship(person: "Beta", relationship: "長期合作並互相信賴的重要盟友"),
          CharacterRelationship(person: "Gamma", relationship: "盟友丙"),
          CharacterRelationship(person: "Delta", relationship: "盟友丁"),
        ],
      ),
      "alpha": character("alpha", "Alpha", "ALPHA001"),
      "beta": character("beta", "Beta", "BETA0001"),
      "gamma": character("gamma", "Gamma", "GAMMA001"),
      "delta": character("delta", "Delta", "DELTA001"),
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CharacterRelationshipGraphView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labelFinder = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith("relationship-edge-label-");
    });
    final nodeFinder = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith("relationship-node-");
    });
    expect(labelFinder, findsNWidgets(4));
    expect(nodeFinder, findsNWidgets(5));

    final shortLabelRect = tester.getRect(
      find.byKey(const ValueKey("relationship-edge-label-hero::0::alpha")),
    );
    final longLabelRect = tester.getRect(
      find.byKey(const ValueKey("relationship-edge-label-hero::1::beta")),
    );
    expect(longLabelRect.width, greaterThan(shortLabelRect.width));

    final heroCenter = tester
        .getRect(find.byKey(const ValueKey("relationship-node-hero")))
        .center;
    final alphaCenter = tester
        .getRect(find.byKey(const ValueKey("relationship-node-alpha")))
        .center;
    final heroToAlpha = alphaCenter - heroCenter;
    final heroToShortLabel = shortLabelRect.center - heroCenter;
    final labelDistanceFromLine =
        (heroToAlpha.dx * heroToShortLabel.dy -
                heroToAlpha.dy * heroToShortLabel.dx)
            .abs() /
        heroToAlpha.distance;
    expect(labelDistanceFromLine, lessThan(1));

    final labelRects = [
      for (var index = 0; index < 4; index++)
        tester.getRect(labelFinder.at(index)),
    ];
    final nodeRects = [
      for (var index = 0; index < 5; index++)
        tester.getRect(nodeFinder.at(index)),
    ];
    for (var labelIndex = 0; labelIndex < labelRects.length; labelIndex++) {
      for (final nodeRect in nodeRects) {
        expect(labelRects[labelIndex].overlaps(nodeRect), isFalse);
      }
      for (
        var otherIndex = labelIndex + 1;
        otherIndex < labelRects.length;
        otherIndex++
      ) {
        expect(
          labelRects[labelIndex].overlaps(labelRects[otherIndex]),
          isFalse,
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("edges from the most connected character are painted first", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData({
      "sparse": character(
        "sparse",
        "Sparse",
        "SPARSE01",
        relationships: const [
          CharacterRelationship(person: "Leaf", relationship: "單一路徑"),
        ],
      ),
      "leaf": character("leaf", "Leaf", "LEAF0001"),
      "hub": character(
        "hub",
        "Hub",
        "HUB00001",
        characterType: "主角",
        relationships: const [
          CharacterRelationship(person: "Alpha", relationship: "密集甲"),
          CharacterRelationship(person: "Beta", relationship: "密集乙"),
          CharacterRelationship(person: "Gamma", relationship: "密集丙"),
        ],
      ),
      "alpha": character("alpha", "Alpha", "ALPHA001"),
      "beta": character("beta", "Beta", "BETA0001"),
      "gamma": character("gamma", "Gamma", "GAMMA001"),
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CharacterRelationshipGraphView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final edgeLabels = tester
        .widgetList<Widget>(
          find.byWidgetPredicate((widget) {
            final key = widget.key;
            return key is ValueKey<String> &&
                key.value.startsWith("relationship-edge-label-");
          }),
        )
        .map((widget) => (widget.key! as ValueKey<String>).value)
        .toList(growable: false);
    expect(edgeLabels, hasLength(4));
    expect(edgeLabels.first, startsWith("relationship-edge-label-hub::"));
    expect(edgeLabels.last, startsWith("relationship-edge-label-sparse::"));
    expect(tester.takeException(), isNull);
  });

  testWidgets("opposite relationships render as two separated one-way edges", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData({
      "alice": character(
        "alice",
        "Alice",
        "ALICE001",
        relationships: const [
          CharacterRelationship(person: "Bob", relationship: "信任"),
        ],
      ),
      "bob": character(
        "bob",
        "Bob",
        "BOB00001",
        relationships: const [
          CharacterRelationship(person: "Alice", relationship: "競爭"),
        ],
      ),
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CharacterRelationshipGraphView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final trustRect = tester.getRect(find.text("信任"));
    final rivalryRect = tester.getRect(find.text("競爭"));
    expect(trustRect.overlaps(rivalryRect), isFalse);
    expect((trustRect.center - rivalryRect.center).distance, greaterThan(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "editable relationship combo creates a missing target and both directions",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(characterDataProvider.notifier).setCharacterData({
        "alice": character("alice", "Alice", "ALICE001"),
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CharacterRelationshipGraphView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("新增關係"));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey("relationship-target-combobox")),
        findsOneWidget,
      );
      final targetField = find.descendant(
        of: find.byKey(const ValueKey("relationship-target-combobox")),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(targetField, "Carol");

      final descriptionContainer = find.byKey(
        const ValueKey("relationship-description-field"),
      );
      final standardDescription = tester.widget<AppTextField>(
        descriptionContainer,
      );
      expect(standardDescription.maxLines, 1);
      await tester.enterText(
        find.descendant(
          of: descriptionContainer,
          matching: find.byType(TextFormField),
        ),
        "朋友",
      );
      await tester.tap(find.text("雙向關係"));
      await tester.pump();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey("bidirectional-relationship-checkbox")),
            )
            .value,
        isTrue,
      );

      await tester.tap(find.text("儲存"));
      await tester.pumpAndSettle();

      final characters = container.read(characterDataProvider);
      expect(characters, hasLength(2));
      final carol = characters.values.singleWhere(
        (entry) => entry.displayName == "Carol",
      );
      expect(
        characters["alice"]?.relationships,
        contains(
          const CharacterRelationship(person: "Carol", relationship: "朋友"),
        ),
      );
      expect(
        carol.relationships,
        contains(
          const CharacterRelationship(person: "Alice", relationship: "朋友"),
        ),
      );
      final graph = const CharacterRelationshipGraphMapper().map(characters);
      expect(graph.edges, hasLength(1));
      expect(graph.edges.single.isBidirectional, isTrue);
      expect(find.text("朋友"), findsOneWidget);

      final relationshipLabel = tester.widget<InkWell>(
        find
            .ancestor(of: find.text("朋友"), matching: find.byType(InkWell))
            .first,
      );
      relationshipLabel.onTap!();
      await tester.pumpAndSettle();
      expect(find.text("Alice ↔ Carol"), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("toolbar fully expands on narrow layouts and starts fitted", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData({
      "alice": character(
        "alice",
        "Alice",
        "ALICE001",
        relationships: const [
          CharacterRelationship(person: "Bob", relationship: "信任"),
        ],
      ),
      "bob": character("bob", "Bob", "BOB00001"),
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CharacterRelationshipGraphView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey("global-preview-button")), findsOneWidget);
    expect(find.byTooltip("全局預覽"), findsOneWidget);
    final searchField = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey("relationship-search-field")),
    );
    expect(searchField.size.width, greaterThan(380));
    final searchFieldRect = tester.getRect(
      find.byKey(const ValueKey("relationship-search-field")),
    );
    final searchButtonRect = tester.getRect(
      find.byKey(const ValueKey("relationship-search-button")),
    );
    expect(searchFieldRect.contains(searchButtonRect.center), isTrue);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final viewerRect = tester.getRect(find.byType(InteractiveViewer));
    final graphCanvas = find.byKey(const ValueKey("relationship-graph-canvas"));
    final initialAliceRect = tester.getRect(
      find.descendant(of: graphCanvas, matching: find.text("Alice")),
    );
    expect(
      viewerRect.overlaps(initialAliceRect),
      isTrue,
      reason: "viewer=$viewerRect, Alice=$initialAliceRect",
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      lessThan(1),
    );

    await tester.tap(find.byKey(const ValueKey("relationship-search-field")));
    await tester.enterText(
      find.byKey(const ValueKey("relationship-search-field")),
      "Bo",
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey("relationship-search-option-Bob")),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey("relationship-search-option-Bob")),
    );
    await tester.pumpAndSettle();
    final editableComboBox = tester.widget<TextField>(
      find.byKey(const ValueKey("relationship-search-field")),
    );
    expect(editableComboBox.controller?.text, "Bob");
    expect(find.text("相鄰關係：1"), findsOneWidget);

    final neighborsToggle = find.byKey(
      const ValueKey("neighbors-only-toggle-button"),
    );
    var neighborsButton = tester.widget<IconButton>(neighborsToggle);
    expect(neighborsButton.isSelected, isFalse);
    expect(neighborsButton.style, isNull);

    await tester.tap(neighborsToggle);
    await tester.pumpAndSettle();
    neighborsButton = tester.widget<IconButton>(neighborsToggle);
    final scheme = Theme.of(tester.element(neighborsToggle)).colorScheme;
    expect(neighborsButton.isSelected, isTrue);
    expect(
      neighborsButton.style?.backgroundColor?.resolve({WidgetState.selected}),
      scheme.primaryContainer,
    );
    expect(
      neighborsButton.style?.foregroundColor?.resolve({WidgetState.selected}),
      scheme.onPrimaryContainer,
    );

    await tester.tap(find.byTooltip("關閉"));
    await tester.pumpAndSettle();
    neighborsButton = tester.widget<IconButton>(neighborsToggle);
    expect(neighborsButton.isSelected, isFalse);
    expect(neighborsButton.style, isNull);
    expect(find.text("相鄰關係：1"), findsNothing);
    expect(
      find.descendant(of: graphCanvas, matching: find.text("Alice")),
      findsOneWidget,
    );
    expect(
      find.descendant(of: graphCanvas, matching: find.text("Bob")),
      findsOneWidget,
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      lessThan(1),
    );
    expect(
      viewerRect.overlaps(
        tester.getRect(
          find.descendant(of: graphCanvas, matching: find.text("Alice")),
        ),
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey("relationship-search-button")));
    await tester.pumpAndSettle();
    expect(find.text("相鄰關係：1"), findsOneWidget);
    await tester.tap(neighborsToggle);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(neighborsToggle).isSelected, isTrue);
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );

    await tester.tap(find.byKey(const ValueKey("global-preview-button")));
    await tester.pumpAndSettle();
    neighborsButton = tester.widget<IconButton>(neighborsToggle);
    expect(neighborsButton.isSelected, isFalse);
    expect(neighborsButton.style, isNull);
    expect(find.text("相鄰關係：1"), findsNothing);
    expect(
      find.descendant(of: graphCanvas, matching: find.text("Alice")),
      findsOneWidget,
    );
    expect(
      find.descendant(of: graphCanvas, matching: find.text("Bob")),
      findsOneWidget,
    );
    expect(
      viewerRect.overlaps(
        tester.getRect(
          find.descendant(of: graphCanvas, matching: find.text("Alice")),
        ),
      ),
      isTrue,
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      lessThan(1),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey("relationship-toolbar-toggle")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("global-preview-button")), findsNothing);

    await tester.tap(find.byKey(const ValueKey("relationship-toolbar-toggle")));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("global-preview-button")), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
