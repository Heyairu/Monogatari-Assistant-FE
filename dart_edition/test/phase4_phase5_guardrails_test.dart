import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/models/world_settings_data.dart";
import "package:monogatari_assistant/modules/characterview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("CharacterEntryData exposes unmodifiable collections", () {
    final entry = CharacterEntryData(
      textFields: const {"name": "Alice"},
      hinderEvents: const [CharacterHinderEvent(event: "e1", solve: "s1")],
      loveToDoList: const ["read"],
      howToShowLove: const {"confess_directly": true},
      commonAbilityValues: const [50.0],
      likeItemList: const ["book"],
    );

    expect(() => entry.textFields["nickname"] = "A", throwsUnsupportedError);
    expect(
      () => entry.hinderEvents.add(const CharacterHinderEvent()),
      throwsUnsupportedError,
    );
    expect(() => entry.loveToDoList.add("write"), throwsUnsupportedError);
    expect(() => entry.howToShowLove["gift"] = false, throwsUnsupportedError);
    expect(() => entry.commonAbilityValues.add(10.0), throwsUnsupportedError);
    expect(() => entry.likeItemList.add("pen"), throwsUnsupportedError);
  });

  test("CharacterDataNotifier uses copy-on-write snapshots", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(characterDataProvider.notifier);
    final characterIds = <String>[];

    for (var index = 0; index < 40; index++) {
      final name = "Character $index";
      final entry = CharacterEntryData.withName(name);
      characterIds.add(entry.characterId);
      expect(
        notifier.setCharacterEntry(
          characterId: entry.characterId,
          entry: entry,
        ),
        isTrue,
      );
      expect(
        notifier.updateCharacterEntry(
          entry.characterId,
          (current) => current.copyWith(
            loveToDoList: [...current.loveToDoList, "task $index"],
            howToShowLove: {
              ...current.howToShowLove,
              "confess_directly": index.isEven,
            },
          ),
        ),
        isTrue,
      );
    }

    final snapshot = container.read(characterDataProvider);
    expect(snapshot.length, 40);
    expect(
      () => snapshot["boom"] = CharacterEntryData.withName("boom"),
      throwsUnsupportedError,
    );

    for (var index = 0; index < 20; index++) {
      expect(
        notifier.renameCharacterEntry(
          characterId: characterIds[index],
          displayName: "Renamed $index",
        ),
        isTrue,
      );
    }

    for (var index = 0; index < 40; index++) {
      expect(notifier.removeCharacterEntry(characterIds[index]), isTrue);
    }

    expect(container.read(characterDataProvider), isEmpty);
  });

  test("WorldSettingsDataNotifier keeps location trees immutable", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(worldSettingsDataProvider.notifier);

    expect(notifier.addLocation(name: "Town"), isTrue);
    expect(notifier.addLocation(name: "Forest"), isTrue);

    final topLevelSnapshot = container.read(worldSettingsDataProvider);
    expect(
      () => topLevelSnapshot.add(LocationData(localName: "Boom")),
      throwsUnsupportedError,
    );

    final townId = topLevelSnapshot.first.id;
    expect(notifier.addLocation(name: "Square", parentId: townId), isTrue);

    final nestedSnapshot = container.read(worldSettingsDataProvider);
    expect(
      () => nestedSnapshot.first.child.add(LocationData(localName: "Boom")),
      throwsUnsupportedError,
    );

    final childId = nestedSnapshot.first.child.first.id;
    expect(
      notifier.updateLocationById(
        childId,
        (current) => current.copyWith(note: "updated note"),
      ),
      isTrue,
    );
    expect(
      notifier.moveLocation(
        sourceId: childId,
        targetId: nestedSnapshot[1].id,
        position: "before",
      ),
      isTrue,
    );
    expect(notifier.removeLocationById(childId), isTrue);
  });

  testWidgets("CharacterView renames without selection regression", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final alice = CharacterEntryData.withName("Alice");
    container
        .read(characterDataProvider.notifier)
        .setCharacterEntry(characterId: alice.characterId, entry: alice);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: CharacterView())),
      ),
    );

    await tester.pumpAndSettle();

    final nameField = _findTextFieldByLabel(tester, "姓名（必填）：");

    await tester.enterText(nameField, "Alice Prime");
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final nameTextField = tester.widget<TextField>(nameField);
    final controller = nameTextField.controller;
    expect(controller, isNotNull);
    expect(controller!.text, "Alice Prime");
    expect(controller.selection.baseOffset, controller.text.length);
    expect(controller.selection.extentOffset, controller.text.length);
    expect(
      container.read(characterDataProvider).entries.single.key,
      alice.characterId,
    );
  });

  testWidgets("CharacterView uses inline custom-field defaults", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final alice = CharacterEntryData.withName("Alice");
    container
        .read(characterDataProvider.notifier)
        .setCharacterEntry(characterId: alice.characterId, entry: alice);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: CharacterView())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("暱稱"), findsOneWidget);
    expect(find.text("阻礙與解決方式"), findsOneWidget);
    final relationshipSummaryField = _findTextFieldByLabel(tester, "人物關係：");
    expect(relationshipSummaryField, findsOneWidget);
    expect(find.text("人物關係"), findsOneWidget);

    await tester.enterText(relationshipSummaryField, "相識多年的朋友");
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(
      container
          .read(characterDataProvider)[alice.characterId]!
          .relationshipSummary,
      "相識多年的朋友",
    );

    final advancedTab = find.widgetWithText(Tab, "進階設定");
    await tester.ensureVisible(advancedTab);
    await tester.pumpAndSettle();
    await tester.tap(advancedTab);
    await tester.pumpAndSettle();
    final socialTile = find.text("社交問卷");
    await tester.ensureVisible(socialTile);
    await tester.tap(socialTile);
    await tester.pumpAndSettle();
    expect(find.text("來自他人的印象"), findsOneWidget);
    expect(find.text("簡述原生家庭"), findsOneWidget);
    expect(find.text("戀愛關係"), findsOneWidget);

    final otherFieldsTile = find.text("其他舊欄位");
    await tester.ensureVisible(otherFieldsTile);
    await tester.tap(otherFieldsTile);
    await tester.pumpAndSettle();
    expect(find.text("喜歡的事物"), findsOneWidget);
    expect(find.text("憧憬的事物"), findsOneWidget);
    expect(find.text("討厭的事物"), findsOneWidget);
    expect(find.text("害怕的事物"), findsOneWidget);
    expect(find.text("喜歡的人事物"), findsNothing);
    expect(find.text("憧憬的人事物"), findsNothing);
    expect(find.text("討厭的人事物"), findsNothing);
    expect(find.text("害怕的人事物"), findsNothing);

    final customFieldsTab = find.widgetWithText(Tab, "自訂資料");
    await tester.ensureVisible(customFieldsTab);
    await tester.tap(customFieldsTab);
    await tester.pumpAndSettle();

    Future<void> addField(String name, CustomFieldType type) async {
      await tester.enterText(_findTextFieldByLabel(tester, "新增欄位名稱"), name);
      await tester.pump();
      if (type != CustomFieldType.text) {
        tester
            .widget<AppDropdownField<CustomFieldType>>(
              find.byType(AppDropdownField<CustomFieldType>),
            )
            .onChanged
            ?.call(type);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip("新增欄位名稱"));
      await tester.pumpAndSettle();
    }

    await addField("說明", CustomFieldType.text);
    await addField("完成度", CustomFieldType.number);
    await addField("公開", CustomFieldType.boolean);
    await addField("標籤", CustomFieldType.list);

    final fields = container
        .read(characterDataProvider)[alice.characterId]!
        .customFields;
    expect(
      fields,
      containsPair(
        "說明",
        const CustomFieldValue(type: CustomFieldType.text, rawValue: ""),
      ),
    );
    expect(
      fields,
      containsPair(
        "完成度",
        const CustomFieldValue(type: CustomFieldType.number, rawValue: "50"),
      ),
    );
    expect(
      fields,
      containsPair(
        "公開",
        const CustomFieldValue(
          type: CustomFieldType.boolean,
          rawValue: "false",
        ),
      ),
    );
    expect(
      fields,
      containsPair(
        "標籤",
        const CustomFieldValue(type: CustomFieldType.list, rawValue: ""),
      ),
    );
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AppDropdownField<CustomFieldType>), findsOneWidget);
    expect(find.byType(LabeledSlider), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, "公開"), findsOneWidget);
    expect(find.text("啟用"), findsNothing);
    expect(find.text("數字（百分比）"), findsNothing);
    expect(find.text("布林"), findsNothing);
    expect(find.text("標籤"), findsNothing);
    expect(find.byTooltip("移除說明"), findsOneWidget);
    expect(find.byTooltip("移除完成度"), findsOneWidget);
    expect(find.byTooltip("移除公開"), findsOneWidget);
    expect(find.byTooltip("移除標籤"), findsOneWidget);
  });

  testWidgets("CharacterView deletes a selected relationship row", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final alice = CharacterEntryData.withName("Alice").copyWith(
      relationships: const [
        CharacterRelationship(person: "Bob", relationship: "朋友"),
      ],
    );
    container
        .read(characterDataProvider.notifier)
        .setCharacterEntry(characterId: alice.characterId, entry: alice);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: CharacterView())),
      ),
    );
    await tester.pumpAndSettle();

    final relationshipRow = find.text("Bob");
    await tester.ensureVisible(relationshipRow);
    await tester.tap(relationshipRow);
    await tester.pumpAndSettle();

    final relationshipEditor = find.byType(AppTwoColumnTableEditor).at(1);
    expect(
      tester.widget<AppTwoColumnTableEditor>(relationshipEditor).isEditing,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppTwoColumnTableEditor>(relationshipEditor).isEditing,
      isFalse,
    );

    await tester.tap(find.text("Bob"));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppTwoColumnTableEditor>(relationshipEditor).isEditing,
      isTrue,
    );
    final relationshipDeleteButton = find.descendant(
      of: relationshipEditor,
      matching: find.byTooltip("刪除"),
    );
    expect(relationshipDeleteButton, findsOneWidget);

    await tester.tap(relationshipDeleteButton);
    await tester.pumpAndSettle();

    expect(
      container.read(characterDataProvider)[alice.characterId]!.relationships,
      isEmpty,
    );
    expect(find.text("Bob"), findsNothing);
  });

  testWidgets("relationship person combo selects a character or free text", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final alice = CharacterEntryData.withName("Alice");
    final bob = CharacterEntryData.withName("Bob");
    final notifier = container.read(characterDataProvider.notifier);
    notifier.setCharacterEntry(characterId: alice.characterId, entry: alice);
    notifier.setCharacterEntry(characterId: bob.characterId, entry: bob);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: CharacterView())),
      ),
    );
    await tester.pumpAndSettle();

    final combo = find.byType(AppComboBoxField);
    await tester.ensureVisible(combo);
    await tester.pumpAndSettle();
    final comboWidget = tester.widget<AppComboBoxField>(combo);
    expect(comboWidget.options, contains("Bob"));
    expect(comboWidget.options, isNot(contains("Alice")));

    final personField = find.descendant(
      of: combo,
      matching: find.byType(TextField),
    );
    await tester.enterText(personField, "Bo");
    await tester.pumpAndSettle();
    final bobOption = find.byKey(const ValueKey("app-combo-option-Bob"));
    expect(bobOption, findsOneWidget);
    await tester.tap(bobOption);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(personField).controller!.text, "Bob");

    final relationshipField = _findTextFieldByLabel(tester, "關係");
    await tester.enterText(relationshipField, "朋友");
    await tester.pump();
    final relationshipEditor = find.byType(AppTwoColumnTableEditor).at(1);
    final addButton = find.descendant(
      of: relationshipEditor,
      matching: find.byTooltip("新增"),
    );
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    notifier.renameCharacterEntry(
      characterId: alice.characterId,
      displayName: "Alice Prime",
    );
    await tester.pumpAndSettle();

    await tester.enterText(personField, "Bob");
    await tester.enterText(relationshipField, "同事");
    await tester.pump();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    var savedAlice = container.read(characterDataProvider)[alice.characterId]!;
    expect(savedAlice.displayName, "Alice Prime");
    expect(savedAlice.relationships, const [
      CharacterRelationship(person: "Bob", relationship: "朋友、同事"),
    ]);

    await tester.enterText(personField, "神秘人");
    await tester.enterText(relationshipField, "恩人");
    await tester.pump();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final relationshipCell = find.byKey(
      const ValueKey("relationship-description-0"),
    );
    await tester.tap(relationshipCell);
    await tester.pump();
    final inlineRelationshipField = find.descendant(
      of: relationshipCell,
      matching: find.byType(TextField),
    );
    expect(inlineRelationshipField, findsOneWidget);
    await tester.enterText(inlineRelationshipField, "摯友");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    savedAlice = container.read(characterDataProvider)[alice.characterId]!;
    expect(
      savedAlice.relationships,
      containsAll([
        const CharacterRelationship(person: "Bob", relationship: "摯友"),
        const CharacterRelationship(person: "神秘人", relationship: "恩人"),
      ]),
    );
  });
}

Finder _findTextFieldByLabel(WidgetTester tester, String label) {
  final textFields = tester
      .widgetList<TextField>(find.byType(TextField))
      .toList();
  final index = textFields.indexWhere(
    (field) =>
        field.decoration?.labelText == label ||
        field.decoration?.hintText == label,
  );

  expect(
    index,
    isNonNegative,
    reason:
        "Unable to find a TextField with label/hint '$label'. Available fields: ${textFields.map((field) => field.decoration?.labelText ?? field.decoration?.hintText ?? '<no decoration>').toList()}",
  );

  return find.byType(TextField).at(index);
}
