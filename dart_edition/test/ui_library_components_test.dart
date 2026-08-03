import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";

Widget _testApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group("UI Library", () {
    testWidgets("ResponsiveSplitView switches between row and column", (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          const SizedBox(
            width: 800,
            child: ResponsiveSplitView(
              primary: Text("Primary"),
              secondary: Text("Secondary"),
            ),
          ),
        ),
      );

      final widePrimary = tester.getTopLeft(find.text("Primary"));
      final wideSecondary = tester.getTopLeft(find.text("Secondary"));
      expect(wideSecondary.dx, greaterThan(widePrimary.dx));
      expect(wideSecondary.dy, widePrimary.dy);

      await tester.pumpWidget(
        _testApp(
          const SizedBox(
            width: 500,
            child: ResponsiveSplitView(
              primary: Text("Primary"),
              secondary: Text("Secondary"),
            ),
          ),
        ),
      );

      final compactPrimary = tester.getTopLeft(find.text("Primary"));
      final compactSecondary = tester.getTopLeft(find.text("Secondary"));
      expect(compactSecondary.dy, greaterThan(compactPrimary.dy));
    });

    testWidgets("AppSectionCard composes a header and empty state", (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          const AppSectionCard(
            title: "Characters",
            icon: Icons.people_outline,
            child: AppEmptyState(
              title: "No characters",
              description: "Create the first character",
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text("Characters"), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      expect(find.text("No characters"), findsOneWidget);
      expect(find.text("Create the first character"), findsOneWidget);
    });

    testWidgets("AppNoticeBanner uses semantic tone and dismisses", (
      tester,
    ) async {
      var dismissed = false;
      await tester.pumpWidget(
        _testApp(
          AppNoticeBanner(
            message: "Development feature",
            tone: AppFeedbackTone.warning,
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
      await tester.tap(find.byTooltip("關閉"));
      expect(dismissed, isTrue);
    });

    testWidgets("AppFeedback displays a centralized snack bar", (tester) async {
      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => AppFeedback.success(context, "Saved"),
              child: const Text("Notify"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Notify"));
      await tester.pump();

      expect(find.text("Saved"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets("AppTextField supports input and validation", (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _testApp(
          Form(
            key: formKey,
            child: AppTextField(
              controller: controller,
              labelText: "Name",
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? "Name is required" : null,
            ),
          ),
        ),
      );

      final inputDecoratorFinder = find.descendant(
        of: find.byType(TextFormField),
        matching: find.byType(InputDecorator),
      );
      final inputDecorator = tester.widget<InputDecorator>(
        inputDecoratorFinder,
      );
      final fieldContext = tester.element(inputDecoratorFinder);
      expect(inputDecorator.decoration.filled, isTrue);
      expect(
        inputDecorator.decoration.fillColor,
        Theme.of(fieldContext).colorScheme.surfaceContainerLowest,
      );
      expect(
        inputDecorator.decoration.contentPadding,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
      final border = inputDecorator.decoration.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(12));

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text("Name is required"), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), "Alice");
      expect(formKey.currentState!.validate(), isTrue);
      expect(controller.text, "Alice");
    });

    testWidgets("AppDropdownField matches AppTextField decoration", (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          Column(
            children: [
              const AppTextField(labelText: "Text"),
              AppDropdownField<String>(
                value: "one",
                labelText: "Dropdown",
                options: const [
                  DropdownOption(value: "one", label: "One"),
                  DropdownOption(value: "two", label: "Two"),
                ],
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );

      final decorations = tester
          .widgetList<InputDecorator>(find.byType(InputDecorator))
          .map((widget) => widget.decoration)
          .toList();
      expect(decorations, hasLength(2));

      final textDecoration = decorations.first;
      final dropdownDecoration = decorations.last;
      expect(dropdownDecoration.filled, textDecoration.filled);
      expect(dropdownDecoration.fillColor, textDecoration.fillColor);
      expect(dropdownDecoration.contentPadding, textDecoration.contentPadding);
      expect(
        (dropdownDecoration.border as OutlineInputBorder).borderRadius,
        (textDecoration.border as OutlineInputBorder).borderRadius,
      );
    });

    testWidgets("ItemActionBar invokes edit and delete callbacks", (
      tester,
    ) async {
      var edited = false;
      var deleted = false;
      await tester.pumpWidget(
        _testApp(
          ItemActionBar.editDelete(
            onEdit: () => edited = true,
            onDelete: () => deleted = true,
          ),
        ),
      );

      await tester.tap(find.byTooltip("重新命名"));
      await tester.tap(find.byTooltip("刪除"));

      expect(edited, isTrue);
      expect(deleted, isTrue);
    });

    testWidgets("CollectionPanel renders empty and populated collections", (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(const CollectionPanel(title: "Plans", emptyTitle: "No plans")),
      );
      expect(find.text("No plans"), findsOneWidget);

      await tester.pumpWidget(
        _testApp(
          CollectionPanel.builder(
            title: "Plans",
            itemCount: 2,
            itemBuilder: (context, index) => Text("Plan $index"),
            footer: const Text("Footer action"),
          ),
        ),
      );
      expect(find.text("Plan 0"), findsOneWidget);
      expect(find.text("Plan 1"), findsOneWidget);
      expect(find.text("Footer action"), findsOneWidget);
    });

    testWidgets("AppTwoColumnTable renders headers, rows, and empty state", (
      tester,
    ) async {
      var selected = false;
      await tester.pumpWidget(
        _testApp(
          AppTwoColumnTable(
            firstHeader: "Setting",
            secondHeader: "Value",
            bodyHeight: 120,
            rows: [
              AppTwoColumnTableRow(
                firstCell: const Text("Weather"),
                secondCell: const Text("Rainy"),
                onTap: () => selected = true,
              ),
            ],
          ),
        ),
      );

      expect(find.text("Setting"), findsOneWidget);
      expect(find.text("Value"), findsOneWidget);
      expect(find.text("Weather"), findsOneWidget);
      final header = tester.widget<ColoredBox>(
        find
            .ancestor(
              of: find.text("Setting"),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      final headerContext = tester.element(find.text("Setting"));
      expect(
        header.color,
        Theme.of(headerContext).colorScheme.surfaceContainerHighest,
      );
      await tester.tap(find.text("Rainy"));
      expect(selected, isTrue);

      await tester.pumpWidget(
        _testApp(
          const AppTwoColumnTable(
            firstHeader: "Setting",
            secondHeader: "Value",
            bodyHeight: 120,
            rows: [],
            emptyState: AppEmptyState(title: "No rows", compact: true),
          ),
        ),
      );

      expect(find.text("No rows"), findsOneWidget);
    });

    testWidgets("AppThreeColumnTable renders three headers and row values", (
      tester,
    ) async {
      var selected = false;
      await tester.pumpWidget(
        _testApp(
          AppThreeColumnTable(
            firstHeader: "Item",
            secondHeader: "Quantity",
            thirdHeader: "Description",
            rows: [
              AppThreeColumnTableRow(
                firstCell: const Text("Pocket watch"),
                secondCell: const Text("1"),
                thirdCell: const Text("Family heirloom"),
                onTap: () => selected = true,
              ),
            ],
          ),
        ),
      );

      expect(find.text("Item"), findsOneWidget);
      expect(find.text("Quantity"), findsOneWidget);
      expect(find.text("Description"), findsOneWidget);
      expect(find.text("Pocket watch"), findsOneWidget);
      expect(find.text("1"), findsOneWidget);
      expect(find.text("Family heirloom"), findsOneWidget);
      await tester.tap(find.text("Pocket watch"));
      expect(selected, isTrue);
    });

    testWidgets("AppTwoColumnTable clears selection on blank tap or Escape", (
      tester,
    ) async {
      var selected = false;
      var clearCount = 0;

      await tester.pumpWidget(
        _testApp(
          AppTwoColumnTable(
            firstHeader: "Setting",
            secondHeader: "Value",
            bodyHeight: 160,
            onSelectionCleared: () {
              selected = false;
              clearCount++;
            },
            rows: [
              AppTwoColumnTableRow(
                firstCell: const Text("Weather"),
                secondCell: const Text("Rainy"),
                onTap: () => selected = true,
              ),
            ],
          ),
        ),
      );

      final table = find.byType(AppTwoColumnTable);
      await tester.tap(find.text("Rainy"));
      expect(selected, isTrue);

      final tableRect = tester.getRect(table);
      await tester.tapAt(Offset(tableRect.center.dx, tableRect.bottom - 8));
      await tester.pump();
      expect(selected, isFalse);
      expect(clearCount, 1);

      await tester.tap(find.text("Rainy"));
      expect(selected, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(selected, isFalse);
      expect(clearCount, 2);
    });

    testWidgets("AppTwoColumnTableEditor shares add and edit behavior", (
      tester,
    ) async {
      final firstController = TextEditingController();
      final secondController = TextEditingController();
      addTearDown(firstController.dispose);
      addTearDown(secondController.dispose);
      var editing = false;
      (String, String)? submitted;
      var deleted = false;

      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) => AppTwoColumnTableEditor(
              firstController: firstController,
              secondController: secondController,
              firstLabel: "Setting",
              secondLabel: "Value",
              isEditing: editing,
              onSubmit: (first, second) {
                submitted = (first, second);
                setState(() => editing = true);
              },
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );

      expect(find.byTooltip("新增"), findsOneWidget);
      final addButton = find.ancestor(
        of: find.byTooltip("新增"),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(addButton).onPressed, isNull);

      await tester.enterText(find.byType(TextFormField).at(0), "Weather");
      await tester.enterText(find.byType(TextFormField).at(1), "Rainy");
      await tester.pump();
      expect(tester.widget<IconButton>(addButton).onPressed, isNotNull);
      await tester.tap(addButton);
      await tester.pump();

      expect(submitted, ("Weather", "Rainy"));
      expect(find.byTooltip("更新"), findsOneWidget);

      await tester.tap(find.byTooltip("刪除"));
      expect(deleted, isTrue);
    });

    testWidgets("AppEditableTableCell edits with a single click", (
      tester,
    ) async {
      var value = "Original";
      var canceled = false;

      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) => AppEditableTableCell(
              value: value,
              onEditCanceled: () => canceled = true,
              onSubmitted: (nextValue) {
                setState(() => value = nextValue);
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text("Original"));
      await tester.pump();
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), "Modified");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(value, "Modified");
      expect(find.text("Modified"), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.text("Modified"));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(canceled, isTrue);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets("LabeledSlider exposes labels and value changes", (
      tester,
    ) async {
      double? changedValue;
      await tester.pumpWidget(
        _testApp(
          LabeledSlider(
            title: "Courage",
            value: 50,
            leftLabel: "Low",
            rightLabel: "High",
            onChanged: (value) => changedValue = value,
          ),
        ),
      );

      expect(find.text("Courage"), findsOneWidget);
      expect(find.text("Low"), findsOneWidget);
      expect(find.text("High"), findsOneWidget);

      tester.widget<Slider>(find.byType(Slider)).onChanged!(75);
      expect(changedValue, 75);
    });

    testWidgets("InlineEditableText switches to editing and submits", (
      tester,
    ) async {
      var editing = false;
      String? submitted;

      await tester.pumpWidget(
        _testApp(
          StatefulBuilder(
            builder: (context, setState) => InlineEditableText(
              value: "Original",
              isEditing: editing,
              onEdit: () => setState(() => editing = true),
              onSubmitted: (value) {
                submitted = value;
                setState(() => editing = false);
              },
              editOnTap: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text("Original"));
      await tester.pump();
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), "Renamed");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, "Renamed");
    });

    testWidgets("AppDialog confirm returns the selected result", (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await AppDialog.confirm(
                  context: context,
                  title: "Delete",
                  message: "Delete this item?",
                  confirmLabel: "Delete now",
                  destructive: true,
                );
              },
              child: const Text("Open"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();
      expect(find.text("Delete this item?"), findsOneWidget);

      await tester.tap(find.text("Delete now"));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets("AppDialog prompt trims and returns text", (tester) async {
      String? result;
      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await AppDialog.prompt(
                  context: context,
                  title: "Rename",
                  initialValue: " Draft ",
                );
              },
              child: const Text("Prompt"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Prompt"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("確定"));
      await tester.pumpAndSettle();

      expect(result, "Draft");
    });
  });
}
