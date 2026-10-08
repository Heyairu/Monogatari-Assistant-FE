import "dart:io";
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_layout.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_mapper.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_view.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_mutations.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_routing.dart";
import "package:monogatari_assistant/models/project_data.dart";
import "package:monogatari_assistant/presentation/providers/project_history_provider.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:monogatari_assistant/bin/ui_library.dart";

Map<String, CharacterEntryData> sample() => {
  "a": const CharacterEntryData(
    characterId: "a",
    displayName: "Alice",
    characterType: "主角",
    relationships: [
      CharacterRelationship(
        person: "Bob",
        relationship: "同事",
        internalRelationship: "信任",
      ),
    ],
  ),
  "b": const CharacterEntryData(
    characterId: "b",
    displayName: "Bob",
    characterType: "重要配角",
    relationships: [
      CharacterRelationship(
        person: "Alice",
        relationship: "同事",
        internalRelationship: "嫉妒",
      ),
    ],
  ),
  "c": const CharacterEntryData(
    characterId: "c",
    displayName: "Carol",
    characterType: "主要反派",
  ),
};

void focus(WidgetTester tester, String id) => tester
    .widget<GestureDetector>(
      find
          .descendant(
            of: find.byKey(ValueKey("relationship-node-$id")),
            matching: find.byType(GestureDetector),
          )
          .first,
    )
    .onTap!();

Offset position(WidgetTester tester, String id) {
  final node = tester.widget<Positioned>(
    find.byKey(ValueKey("relationship-node-$id")),
  );
  return Offset(node.left!, node.top!);
}

Future<void> pumpGraph(
  WidgetTester tester,
  ProviderContainer container, {
  int session = 0,
  String? fontFamily,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(fontFamily: fontFamily),
        home: Scaffold(
          body: RepaintBoundary(
            key: const ValueKey("preview"),
            child: CharacterRelationshipGraphView(projectSessionId: session),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("merge icon toggles matching opposite channels both ways", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData(sample());
    await pumpGraph(tester, container);
    tester
        .widget<AppMenuButton<CharacterRelationshipDisplayMode>>(
          find.byKey(const ValueKey("relationship-display-selector")),
        )
        .onChanged!(CharacterRelationshipDisplayMode.both);
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey("relationship-merge-toggle"));
    final layer = find.byKey(const ValueKey("relationship-edge-layer"));
    int edgeCount() {
      final painter = tester.widget<CustomPaint>(layer).painter as dynamic;
      return (painter.geometries as Map<String, EdgeGeometry>).length;
    }

    final originalPosition = position(tester, "a");
    expect(tester.widget<NeonIconButton>(toggle).selected, isTrue);
    expect(edgeCount(), 3);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<NeonIconButton>(toggle).selected, isFalse);
    expect(edgeCount(), 4);
    expect(position(tester, "a"), originalPosition);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<NeonIconButton>(toggle).selected, isTrue);
    expect(edgeCount(), 3);
    expect(position(tester, "a"), originalPosition);
    expect(container.read(characterDataProvider), sample());
    expect(tester.takeException(), isNull);
  });

  testWidgets("tap a drawn internal curve selects that exact channel", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData(sample());
    await pumpGraph(tester, container);
    tester
        .widget<AppMenuButton<CharacterRelationshipDisplayMode>>(
          find.byKey(const ValueKey("relationship-display-selector")),
        )
        .onChanged!(CharacterRelationshipDisplayMode.both);
    tester
        .widget<NeonIconButton>(
          find.byKey(const ValueKey("relationship-merge-toggle")),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    final layer = find.byKey(const ValueKey("relationship-edge-layer"));
    final painter = tester.widget<CustomPaint>(layer).painter as dynamic;
    final geometry =
        (painter.geometries as Map<String, EdgeGeometry>)["b::0::a::internal"]!;
    final point = quadraticPoint(
      geometry.start,
      geometry.control,
      geometry.end,
      .5,
    );
    final box = tester.renderObject<RenderBox>(layer);
    await tester.tapAt(box.localToGlobal(point));
    await tester.pumpAndSettle();
    final selectedPainter =
        tester.widget<CustomPaint>(layer).painter as dynamic;
    expect(selectedPainter.selectedEdgeId, "b::0::a::internal");
    expect(
      identical(
        (selectedPainter.geometries
            as Map<String, EdgeGeometry>)["b::0::a::internal"],
        geometry,
      ),
      isTrue,
    );
    expect(find.text("Alice 與 Bob"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test("channel edits remain reversible through existing project history", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final project = ProjectData.empty()..characterData = sample();
    final history = container.read(projectHistoryProvider.notifier);
    ProjectHistoryEntry entry() => ProjectHistoryEntry(
      data: project,
      pageIndex: 6,
      selectedSegID: null,
      selectedChapID: null,
      cursorOffset: 0,
    );
    final original = entry();
    history.reset(original);
    final edge = const CharacterRelationshipGraphMapper()
        .map(project.characterData)
        .edges
        .single;
    project.characterData = updateCharacterRelationshipChannel(
      project.characterData,
      sources: edge.sources,
      layer: edge.layer,
      description: "朋友",
    )!;
    final edited = entry();
    expect(history.record(edited), isTrue);
    final undo = history.undo(edited)!;
    expect(
      undo.data.characterData["a"]!.relationships.single.relationship,
      "同事",
    );
    final redo = history.redo(undo)!;
    expect(
      redo.data.characterData["a"]!.relationships.single.relationship,
      "朋友",
    );
    expect(
      redo.data.characterData["a"]!.relationships.single.internalRelationship,
      "信任",
    );
    expect(
      redo.data.characterData["b"]!.relationships.single.internalRelationship,
      "嫉妒",
    );
  });

  testWidgets("repair unresolved target keeps both relationship layers", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final data = sample();
    data["a"] = data["a"]!.copyWith(
      relationships: const [
        CharacterRelationship(
          person: "Ghost",
          relationship: "同事",
          internalRelationship: "信任",
        ),
      ],
    );
    container.read(characterDataProvider.notifier).setCharacterData(data);
    await pumpGraph(tester, container);
    focus(tester, "a");
    await tester.pumpAndSettle();
    final neighbors = find.byWidgetPredicate(
      (w) =>
          w is ListTile &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            "relationship-neighbor-",
          ),
    );
    tester.widget<ListTile>(neighbors.first).onTap!();
    await tester.pumpAndSettle();
    final repair = find.text("修正目標人物").first;
    await tester.ensureVisible(repair);
    await tester.tap(repair);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey("relationship-repair-target")),
        matching: find.byType(TextFormField),
      ),
      "Bob",
    );
    await tester.tap(find.text("儲存"));
    await tester.pumpAndSettle();
    final saved = container
        .read(characterDataProvider)["a"]!
        .relationships
        .single;
    expect(saved.person, "Bob");
    expect(saved.relationship, "同事");
    expect(saved.internalRelationship, "信任");
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "four-channel focus, filter and merge preserve positions; merged edit and delete preserve reverse feelings",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(characterDataProvider.notifier).setCharacterData(sample());
      await pumpGraph(tester, container);
      expect(find.text("外在：同事"), findsNothing);
      final initial = {
        for (final id in ["a", "b", "c"]) id: position(tester, id),
      };
      final selector = find.byKey(
        const ValueKey("relationship-display-selector"),
      );
      tester
          .widget<AppMenuButton<CharacterRelationshipDisplayMode>>(selector)
          .onChanged!(CharacterRelationshipDisplayMode.both);
      await tester.pumpAndSettle();
      focus(tester, "a");
      await tester.pumpAndSettle();
      expect(position(tester, "a"), initial["a"]);
      final neighbors = find.byWidgetPredicate(
        (w) =>
            w is ListTile &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              "relationship-neighbor-",
            ),
      );
      expect(neighbors, findsNWidgets(3));
      tester.widget<ListTile>(neighbors.first).onTap!();
      await tester.pumpAndSettle();
      expect(find.text("Alice → Bob · 外在"), findsOneWidget);
      expect(find.text("Bob → Alice · 外在"), findsOneWidget);
      expect(find.text("Alice → Bob · 內在"), findsOneWidget);
      expect(find.text("Bob → Alice · 內在"), findsOneWidget);
      final edit = find.byKey(const ValueKey("relationship-edit-b-external"));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        "朋友",
      );
      await tester.tap(find.text("儲存"));
      await tester.pumpAndSettle();
      var data = container.read(characterDataProvider);
      expect(data["b"]!.relationships.single.relationship, "朋友");
      expect(data["b"]!.relationships.single.internalRelationship, "嫉妒");
      expect(data["a"], sample()["a"]);
      for (final id in initial.keys) {
        expect(position(tester, id), initial[id]);
      }
      focus(tester, "a");
      await tester.pumpAndSettle();
      tester.widget<ListTile>(neighbors.first).onTap!();
      await tester.pumpAndSettle();
      final delete = find.byKey(
        const ValueKey("relationship-delete-a-external"),
      );
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.textContaining("另一類型與反向關係會保留"), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, "刪除"));
      await tester.pumpAndSettle();
      data = container.read(characterDataProvider);
      expect(data["a"]!.relationships.single.relationship, isEmpty);
      expect(data["a"]!.relationships.single.internalRelationship, "信任");
      expect(data["b"]!.relationships.single.relationship, "朋友");
      for (final id in initial.keys) {
        expect(position(tester, id), initial[id]);
      }
    },
  );

  testWidgets(
    "dragging uses canvas coordinates; pins, neighbors and layout modes keep stable positions",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(characterDataProvider.notifier).setCharacterData(sample());
      await pumpGraph(tester, container);
      // Leave enough viewport height and make real transformed gestures observable.
      await tester.tap(
        find.byKey(const ValueKey("relationship-toolbar-toggle")),
      );
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final beforeTransform = viewer.transformationController!.value.clone();
      final before = position(tester, "a");
      final beforeScreen = tester.getCenter(
        find.byKey(const ValueKey("relationship-node-a")),
      );
      await tester.drag(
        find.byKey(const ValueKey("relationship-node-a")),
        const Offset(100, 60),
      );
      await tester.pumpAndSettle();
      final after = position(tester, "a");
      expect((after - before).distance, greaterThan(40));
      expect(viewer.transformationController!.value, beforeTransform);
      final afterScreen = tester.getCenter(
        find.byKey(const ValueKey("relationship-node-a")),
      );
      expect((afterScreen - beforeScreen).dx, closeTo(100, 3));
      expect((afterScreen - beforeScreen).dy, closeTo(60, 3));
      final pin = find.byKey(const ValueKey("relationship-pin-a"));
      await tester.ensureVisible(pin);
      await tester.tap(pin);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey("relationship-toolbar-toggle")),
      );
      await tester.pumpAndSettle();
      final rearrange = find.byTooltip("自動重新排列");
      await tester.ensureVisible(rearrange);
      await tester.tap(rearrange);
      await tester.pumpAndSettle();
      expect(position(tester, "a"), after);
      tester
          .widget<AppMenuButton<CharacterGraphLayoutMode>>(
            find.byKey(const ValueKey("relationship-layout-selector")),
          )
          .onChanged!(CharacterGraphLayoutMode.clusters);
      await tester.pumpAndSettle();
      expect(position(tester, "a"), after);
      final cPosition = position(tester, "c");
      tester
          .widget<NeonIconButton>(
            find.byKey(const ValueKey("neighbors-only-toggle-button")),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("relationship-node-c")), findsNothing);
      tester
          .widget<NeonIconButton>(
            find.byKey(const ValueKey("neighbors-only-toggle-button")),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(position(tester, "c"), cPosition);
      await pumpGraph(tester, container, session: 1);
      focus(tester, "a");
      await tester.pumpAndSettle();
      expect(find.text("釘選位置"), findsOneWidget);
      expect(find.text("解除釘選"), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "four-channel pair panel remains readable and supports collapse",
    (tester) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = previousShadows);
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(characterDataProvider.notifier).setCharacterData(sample());
      String? previewFont;
      await tester.runAsync(() async {
        final fontPath = Platform.environment["RELATIONSHIP_PREVIEW_FONT"];
        final iconPath = Platform.environment["RELATIONSHIP_PREVIEW_ICONS"];
        if (fontPath != null) {
          final loader = FontLoader("RelationshipPreview");
          loader.addFont(
            Future.value(
              ByteData.sublistView(await File(fontPath).readAsBytes()),
            ),
          );
          await loader.load();
          previewFont = "RelationshipPreview";
        }
        if (iconPath != null) {
          final loader = FontLoader("MaterialIcons");
          loader.addFont(
            Future.value(
              ByteData.sublistView(await File(iconPath).readAsBytes()),
            ),
          );
          await loader.load();
        }
      });
      await pumpGraph(tester, container, fontFamily: previewFont);
      tester
          .widget<AppMenuButton<CharacterRelationshipDisplayMode>>(
            find.byKey(const ValueKey("relationship-display-selector")),
          )
          .onChanged!(CharacterRelationshipDisplayMode.both);
      tester
          .widget<NeonIconButton>(
            find.byKey(const ValueKey("relationship-merge-toggle")),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      focus(tester, "a");
      await tester.pumpAndSettle();
      final neighbor = find.byKey(
        const ValueKey("relationship-neighbor-a::0::b::external"),
      );
      tester.widget<ListTile>(neighbor).onTap!();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey("relationship-edit-a-internal")),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey("relationship-edit-b-internal")),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey("relationship-toolbar-toggle")),
      );
      await tester.pumpAndSettle();
      // Save a local visual QA artifact, outside the tracked source tree.
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey("preview")),
        );
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          ".dart_tool/relationship_layout_preview.png",
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.ensureVisible(
        find.byKey(const ValueKey("relationship-panel-toggle")),
      );
      await tester.tap(find.byKey(const ValueKey("relationship-panel-toggle")));
      await tester.pumpAndSettle();
      expect(find.byTooltip("展開詳細資料"), findsOneWidget);
      expect(
        find.byKey(const ValueKey("relationship-edit-a-internal")),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      debugDisableShadows = previousShadows;
    },
  );
}
