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
  }) {
    return CharacterEntryData.withName(name).copyWith(
      characterId: id,
      displayName: name,
      legacyFields: {"nanoId": nanoId},
      relationships: relationships,
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
