import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

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

    for (var index = 0; index < 40; index++) {
      final name = "Character $index";
      expect(
        notifier.setCharacterEntry(
          name: name,
          entry: CharacterEntryData.withName(name),
        ),
        isTrue,
      );
      expect(
        notifier.updateCharacterEntry(
          name,
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
          oldName: "Character $index",
          newName: "Renamed $index",
        ),
        isTrue,
      );
    }

    for (var index = 0; index < 40; index++) {
      final targetName = index < 20 ? "Renamed $index" : "Character $index";
      expect(notifier.removeCharacterEntry(targetName), isTrue);
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

    container
        .read(characterDataProvider.notifier)
        .setCharacterEntry(
          name: "Alice",
          entry: CharacterEntryData.withName("Alice"),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: CharacterView())),
      ),
    );

    await tester.pumpAndSettle();

    final nameField = _findTextFieldByLabel(tester, "姓名：");

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
