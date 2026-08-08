import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/file.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/models/character_snapshot_data.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/project_migrator.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/modules/characterview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  group("Character snapshots", () {
    const characterId = "character-1";
    const sceneA = "scene-a";
    const sceneB = "scene-b";

    TimelineDocumentData timeline({int sceneATick = 10}) {
      return TimelineDocumentData(
        tracks: const [TimelineTrackData(trackUUID: "track", name: "主線")],
        placements: [
          TimelinePlacementData(
            placementUUID: "placement-a",
            sceneUUID: sceneA,
            trackUUID: "track",
            startTick: sceneATick,
          ),
          const TimelinePlacementData(
            placementUUID: "placement-b",
            sceneUUID: sceneB,
            trackUUID: "track",
            startTick: 20,
          ),
        ],
      );
    }

    test("baseline and Scene changes resolve in timeline order", () {
      final baseline = CharacterStateBaseline(
        characterId: characterId,
        patch: CharacterStatePatch.fromState(
          CharacterSnapshotState(
            statusEntries: const [
              CharacterProfileTableEntry(name: "所在地", description: "家"),
            ],
          ),
        ),
      );
      final changes = [
        CharacterStateChange(
          stateChangeId: "change-b",
          characterId: characterId,
          sceneUUID: sceneB,
          fallbackTick: 2,
          patch: CharacterStatePatch(
            relationships: const [
              CharacterRelationship(person: "守衛", relationship: "敵對"),
            ],
          ),
        ),
        CharacterStateChange(
          stateChangeId: "change-a",
          characterId: characterId,
          sceneUUID: sceneA,
          sourcePlacementUUID: "placement-a",
          fallbackTick: 99,
          patch: CharacterStatePatch(
            statusEntries: const [
              CharacterProfileTableEntry(name: "所在地", description: "王城"),
            ],
          ),
        ),
      ];

      final beforeA = resolveCharacterSnapshot(
        characterId: characterId,
        baseline: baseline,
        changes: changes,
        timeline: timeline(),
        atTick: 9,
      );
      final atA = resolveCharacterSnapshot(
        characterId: characterId,
        baseline: baseline,
        changes: changes,
        timeline: timeline(),
        atTick: 10,
      );
      final atB = resolveCharacterSnapshot(
        characterId: characterId,
        baseline: baseline,
        changes: changes,
        timeline: timeline(),
        atTick: 20,
      );

      expect(beforeA.state.statusEntries.single.description, "家");
      expect(atA.state.statusEntries.single.description, "王城");
      expect(atA.state.relationships, isEmpty);
      expect(atB.state.relationships.single.person, "守衛");
    });

    test(
      "snapshot follows its Scene placement and falls back when removed",
      () {
        final change = CharacterStateChange(
          stateChangeId: "change-a",
          characterId: characterId,
          sceneUUID: sceneA,
          sourcePlacementUUID: "placement-a",
          fallbackTick: 7,
        );

        expect(
          resolveCharacterStateChangeTime(change, timeline()).resolvedTick,
          10,
        );
        expect(
          resolveCharacterStateChangeTime(
            change,
            timeline(sceneATick: 30),
          ).resolvedTick,
          30,
        );
        final fallback = resolveCharacterStateChangeTime(
          change,
          TimelineDocumentData.initial(),
        );
        expect(fallback.resolvedTick, 7);
        expect(fallback.usesFallbackTick, isTrue);
      },
    );

    test("copying a snapshot creates an independent full-state patch", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(timelineDocumentProvider.notifier).setDocument(timeline());
      final source = CharacterSnapshotState(
        conflicts: const [
          CharacterConflict(obstacle: "城門封鎖", resolution: "取得通行證"),
        ],
        possessions: const [
          CharacterPossessionEntry(name: "短劍", quantity: "1"),
          CharacterPossessionEntry(name: "地圖", quantity: "1"),
        ],
        customFields: const {"偽裝": CustomFieldValue(rawValue: "失效")},
      );

      final copied = container
          .read(characterStateChangesProvider.notifier)
          .duplicateSnapshotToScene(
            characterId: characterId,
            source: source,
            sceneUUID: sceneB,
            sourcePlacementUUID: "placement-b",
            fallbackTick: 20,
          );
      final resolved = copied.patch.applyTo(
        CharacterSnapshotState(
          customFields: const {"舊狀態": CustomFieldValue(rawValue: "應被清除")},
        ),
      );

      expect(resolved, source);
      expect(resolved.possessions, isNot(same(source.possessions)));
    });

    test("project XML round-trips baseline and Scene snapshots", () {
      final project = ProjectData.empty()
        ..characterData = {
          characterId: CharacterEntryData(
            characterId: characterId,
            displayName: "艾莉絲",
          ),
        }
        ..outlineData = [
          StorylineData(
            storylineName: "主線",
            scenes: [
              StoryEventData(
                storyEvent: "相遇",
                scenes: [SceneData(sceneUUID: sceneA, sceneName: "城門")],
              ),
            ],
          ),
        ]
        ..timelineDocument = timeline()
        ..characterStateBaselines = {
          characterId: CharacterStateBaseline(
            characterId: characterId,
            patch: CharacterStatePatch(
              statusEntries: const [
                CharacterProfileTableEntry(name: "所在地", description: "家"),
              ],
            ),
          ),
        }
        ..characterStateChanges = [
          CharacterStateChange(
            stateChangeId: "change-a",
            characterId: characterId,
            sceneUUID: sceneA,
            sourcePlacementUUID: "placement-a",
            fallbackTick: 10,
            patch: CharacterStatePatch(
              conflicts: const [
                CharacterConflict(obstacle: "遭伏擊", resolution: "撤退"),
              ],
              relationships: const [
                CharacterRelationship(person: "守衛", relationship: "敵對"),
              ],
              organizations: const [
                CharacterProfileTableEntry(name: "調查局", description: "探員"),
              ],
              statusEntries: const [
                CharacterProfileTableEntry(name: "健康狀態", description: "受傷"),
              ],
              possessions: const [
                CharacterPossessionEntry(name: "短劍", quantity: "1"),
              ],
              customFields: const {
                "偽裝": CustomFieldValue(
                  type: CustomFieldType.boolean,
                  rawValue: "false",
                ),
              },
            ),
            note: "城門衝突",
          ),
        ];

      final xml = FileService.generateProjectXML(project);
      final reopened = FileService.parseProjectXMLWithMetadata(xml).data;

      expect(
        reopened
            .characterStateBaselines[characterId]!
            .resolvedState
            .statusEntries
            .single
            .description,
        "家",
      );
      expect(reopened.characterStateChanges, hasLength(1));
      final change = reopened.characterStateChanges.single;
      expect(change.sceneUUID, sceneA);
      expect(change.sourcePlacementUUID, "placement-a");
      expect(change.patch.conflicts!.single.obstacle, "遭伏擊");
      expect(change.patch.relationships!.single.person, "守衛");
      expect(change.patch.organizations!.single.name, "調查局");
      expect(change.patch.statusEntries!.single.description, "受傷");
      expect(change.patch.possessions!.single.name, "短劍");
      expect(change.patch.customFields!["偽裝"]!.type, CustomFieldType.boolean);
      expect(change.note, "城門衝突");
    });

    test("1.11 baseline tables migrate into the default character card", () {
      final source = ProjectData.empty()
        ..characterData = {
          characterId: const CharacterEntryData(
            characterId: characterId,
            displayName: "艾莉絲",
            organizations: [
              CharacterProfileTableEntry(name: "舊組織", description: "成員"),
            ],
          ),
        }
        ..characterStateBaselines = {
          characterId: CharacterStateBaseline(
            characterId: characterId,
            patch: CharacterStatePatch(
              statusEntries: const [
                CharacterProfileTableEntry(name: "所在地", description: "王城"),
              ],
              possessions: const [
                CharacterPossessionEntry(name: "短劍", quantity: "1"),
              ],
              customFields: const {"稱號": CustomFieldValue(rawValue: "勇者")},
            ),
          ),
        };

      final migrated = ProjectMigrator.migrate(
        sourceVersion: "1.11",
        parsedData: source,
      );
      final character = migrated.data.characterData[characterId]!;

      expect(migrated.wasMigrated, isTrue);
      expect(migrated.data.characterStateBaselines, isEmpty);
      expect(character.organizations.single.name, "舊組織");
      expect(character.statusEntries.single.description, "王城");
      expect(character.possessions.single.name, "短劍");
      expect(character.customFields["稱號"]!.rawValue, "勇者");
    });

    testWidgets("CharacterView previews and quickly adds a Scene snapshot", (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(characterDataProvider.notifier)
          .setCharacterEntry(
            characterId: characterId,
            entry: const CharacterEntryData(
              characterId: characterId,
              displayName: "艾莉絲",
              statusEntries: [
                CharacterProfileTableEntry(name: "健康狀態", description: "健康"),
              ],
              customFields: {"稱號": CustomFieldValue(rawValue: "新人")},
            ),
          );
      container.read(outlineDataProvider.notifier).setOutlineData([
        StorylineData(
          storylineName: "主線",
          scenes: [
            StoryEventData(
              storyEvent: "相遇",
              scenes: [SceneData(sceneUUID: sceneA, sceneName: "城門")],
            ),
          ],
        ),
      ]);
      container.read(timelineDocumentProvider.notifier).setDocument(timeline());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: CharacterView())),
        ),
      );
      await tester.pumpAndSettle();
      final combo = find.byKey(
        const ValueKey("character-snapshot-combo-character-1-__baseline__"),
      );
      expect(combo, findsOneWidget);
      final dropdown = find.descendant(
        of: combo,
        matching: find.byType(DropdownButton<String>),
      );
      expect(
        tester.widget<DropdownButton<String>>(dropdown).value,
        "__baseline__",
      );
      final addButton = find.byKey(
        const ValueKey("character-snapshot-toolbar-add"),
      );
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text("綁定 Scene"), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, "建立快照"));
      await tester.pumpAndSettle();

      final changesAfterDialog = container.read(characterStateChangesProvider);
      expect(changesAfterDialog, hasLength(1));
      final created = changesAfterDialog.single;
      final seeded = created.patch.applyTo(CharacterSnapshotState());
      expect(seeded.statusEntries.single.description, "健康");
      expect(seeded.customFields["稱號"]!.rawValue, "新人");

      final statusSection = find.text("角色狀態").first;
      await tester.ensureVisible(statusSection);
      await tester.tap(statusSection);
      await tester.pumpAndSettle();
      final statusEditor = find.byWidgetPredicate(
        (widget) =>
            widget is AppTwoColumnTableEditor && widget.firstLabel == "狀態",
      );
      await tester.ensureVisible(statusEditor);
      final statusFields = find.descendant(
        of: statusEditor,
        matching: find.byType(TextField),
      );
      await tester.enterText(statusFields.at(0), "所在地");
      await tester.enterText(statusFields.at(1), "王城");
      tester
          .widget<AppTwoColumnTableEditor>(statusEditor)
          .onSubmit("所在地", "王城");
      await tester.pumpAndSettle();

      final customTab = find.widgetWithText(Tab, "自訂資料");
      await tester.ensureVisible(customTab);
      await tester.tap(customTab);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey("custom-text-稱號")),
        "英雄",
      );
      await tester.pumpAndSettle();

      final changes = container.read(characterStateChangesProvider);
      expect(changes, hasLength(1));
      expect(changes.single.sceneUUID, sceneA);
      final edited = changes.single.patch.applyTo(CharacterSnapshotState());
      expect(edited.statusEntries.last.description, "王城");
      expect(edited.customFields["稱號"]!.rawValue, "英雄");
      expect(
        container
            .read(characterDataProvider)[characterId]!
            .statusEntries
            .length,
        1,
      );
      await tester.tap(find.widgetWithText(Tab, "角色卡"));
      await tester.pumpAndSettle();
      final nameField = find.byWidgetPredicate(
        (widget) => widget is CharacterTextField && widget.label == "姓名（必填）：",
      );
      expect(nameField, findsOneWidget);
      expect(tester.widget<CharacterTextField>(nameField).enabled, isFalse);
      expect(find.textContaining("正在編輯 Scene 快照"), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey("character-snapshot-toolbar-copy")),
      );
      await tester.pumpAndSettle();
      expect(find.text("複製 城門"), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, "建立快照"));
      await tester.pumpAndSettle();
      final copiedChanges = container.read(characterStateChangesProvider);
      expect(copiedChanges, hasLength(2));
      expect(
        copiedChanges.last.patch
            .applyTo(CharacterSnapshotState())
            .statusEntries
            .last
            .description,
        "王城",
      );
      expect(
        copiedChanges.last.patch
            .applyTo(CharacterSnapshotState())
            .customFields["稱號"]!
            .rawValue,
        "英雄",
      );
    });

    testWidgets(
      "quick Scene dialog edits large and middle boxes and scrubs Tick",
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container
            .read(characterDataProvider.notifier)
            .setCharacterEntry(
              characterId: characterId,
              entry: const CharacterEntryData(
                characterId: characterId,
                displayName: "艾莉絲",
              ),
            );
        container
            .read(timelineDocumentProvider.notifier)
            .setDocument(
              const TimelineDocumentData(
                tracks: [TimelineTrackData(trackUUID: "track", name: "主線")],
                placements: [
                  TimelinePlacementData(
                    placementUUID: "large-existing",
                    trackUUID: "track",
                    level: TimelineElementLevel.large,
                    startTick: 0,
                    durationTicks: 24,
                    label: "第一幕",
                  ),
                  TimelinePlacementData(
                    placementUUID: "middle-existing",
                    parentPlacementUUID: "large-existing",
                    trackUUID: "track",
                    level: TimelineElementLevel.middle,
                    startTick: 0,
                    durationTicks: 4,
                    label: "序章",
                  ),
                ],
              ),
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: CharacterView())),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey("character-snapshot-toolbar-add")),
        );
        await tester.pumpAndSettle();

        final largeCombo = find.byKey(
          const ValueKey("snapshot-large-box-combo"),
        );
        final middleCombo = find.byKey(
          const ValueKey("snapshot-middle-box-combo"),
        );
        expect(largeCombo, findsOneWidget);
        expect(middleCombo, findsOneWidget);
        expect(
          tester.widget<AppComboBoxField>(largeCombo).options,
          contains("第一幕"),
        );
        expect(
          tester.widget<AppComboBoxField>(middleCombo).options,
          contains("序章"),
        );
        expect(find.text("中箱：序章"), findsOneWidget);

        await tester.enterText(
          find.descendant(of: middleCombo, matching: find.byType(TextField)),
          "轉折事件",
        );
        await tester.pumpAndSettle();
        expect(find.text("大箱：第一幕"), findsOneWidget);

        await tester.enterText(
          find.descendant(of: largeCombo, matching: find.byType(TextField)),
          "第二幕",
        );
        await tester.pumpAndSettle();
        expect(find.text("全域預覽"), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey("snapshot-small-box-name")),
          "新遭遇",
        );

        expect(
          find.byKey(const ValueKey("character-snapshot-tick-scrubber")),
          findsOneWidget,
        );
        final timelineCanvas = find.byKey(
          const ValueKey("snapshot-timeline-canvas"),
        );
        expect(timelineCanvas, findsOneWidget);
        await tester.ensureVisible(timelineCanvas);
        await tester.pumpAndSettle();
        await tester.tapAt(
          Offset(
            tester.getTopRight(timelineCanvas).dx - 24,
            tester.getCenter(timelineCanvas).dy,
          ),
        );
        await tester.pumpAndSettle();
        final tickField = find.byKey(
          const ValueKey("snapshot-tick-field"),
          skipOffstage: false,
        );
        await tester.ensureVisible(tickField);
        await tester.pumpAndSettle();
        expect(
          tester.widget<AppTextField>(tickField).controller?.text,
          isNot("0"),
        );
        await tester.enterText(tickField, "$timelineMaximumTick");
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey("character-snapshot-tick-scrubber")),
          findsOneWidget,
        );
        expect(
          tester.widget<AppTextField>(tickField).controller?.text,
          "$timelineMaximumTick",
        );

        final preview = find.byKey(
          const ValueKey("character-snapshot-tick-scrubber"),
        );
        expect(preview, findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey("character-snapshot-dialog-confirm")),
        );
        await tester.pumpAndSettle();

        final document = container.read(timelineDocumentProvider);
        final large = document.placements.firstWhere(
          (item) =>
              item.level == TimelineElementLevel.large && item.label == "第二幕",
        );
        final middle = document.placements.firstWhere(
          (item) =>
              item.level == TimelineElementLevel.middle && item.label == "轉折事件",
        );
        final small = document.placements.firstWhere(
          (item) =>
              item.level == TimelineElementLevel.small && item.label == "新遭遇",
        );
        expect(middle.parentPlacementUUID, large.placementUUID);
        expect(small.parentPlacementUUID, middle.placementUUID);
        expect(small.startTick, timelineMaximumNodeTick);
        expect(small.endTick, timelineMaximumTick);
        expect(small.sceneUUID, isNotEmpty);
        expect(
          container.read(characterStateChangesProvider).single.sceneUUID,
          small.sceneUUID,
        );
      },
    );
  });
}
