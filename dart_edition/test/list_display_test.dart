import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.light,
  double fontSize = 14,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  theme: brightness == Brightness.light
      ? AppTheme.getLightTheme(fontSize, Colors.blue)
      : AppTheme.getDarkTheme(fontSize, Colors.blue),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(textDirection: direction, child: child!),
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets("plain rows and list cards share text roles in both themes", (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              ListTile(
                title: Text("List title"),
                subtitle: Text("List summary"),
              ),
              AppListCard(
                title: Text("Card title"),
                subtitle: Text("Card summary"),
              ),
            ],
          ),
          brightness: brightness,
        ),
      );
      final titleStyle = DefaultTextStyle.of(
        tester.element(find.text("List title")),
      ).style;
      final cardStyle = DefaultTextStyle.of(
        tester.element(find.text("Card title")),
      ).style;
      final summaryStyle = DefaultTextStyle.of(
        tester.element(find.text("List summary")),
      ).style;
      final cardSummaryStyle = DefaultTextStyle.of(
        tester.element(find.text("Card summary")),
      ).style;
      expect(cardStyle.fontSize, titleStyle.fontSize);
      expect(cardStyle.color, titleStyle.color);
      expect(cardSummaryStyle.fontSize, summaryStyle.fontSize);
      expect(cardSummaryStyle.color, summaryStyle.color);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets("narrow cards preserve scaled actions and move them below text", (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: 260,
              child: AppListCard(
                title: const Text("A long title that wraps without clipping"),
                subtitle: const Text("Supporting information remains readable"),
                leading: const Icon(Icons.folder_outlined),
                trailing: ItemActionBar.editDelete(
                  onEdit: () {},
                  onDelete: () {},
                ),
              ),
            ),
            fontSize: 20,
            scale: scale,
            direction: direction,
          ),
        );
        expect(tester.takeException(), isNull);
        final titleRect = tester.getRect(find.textContaining("A long title"));
        final summaryRect = tester.getRect(find.textContaining("Supporting"));
        final actionsRect = tester.getRect(find.byType(ItemActionBar));
        final cardRect = tester.getRect(find.byType(AppListCard));
        expect(actionsRect.top, greaterThan(summaryRect.bottom));
        expect(titleRect.left, greaterThanOrEqualTo(cardRect.left));
        expect(titleRect.right, lessThanOrEqualTo(cardRect.right));
        expect(actionsRect.left, greaterThanOrEqualTo(cardRect.left));
        expect(actionsRect.right, lessThanOrEqualTo(cardRect.right));
        for (final button in find.byType(IconButton).evaluate()) {
          expect(
            tester.getSize(find.byWidget(button.widget)).height,
            AppControlSize.heightForFontSize(20 * scale),
          );
        }
      }
    }
  });

  testWidgets("card actions respect the 320dp layout boundary", (tester) async {
    for (final width in [319.0, 320.0]) {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: width,
            child: AppListCard(
              title: const Text("Title"),
              trailing: ItemActionBar.editDelete(
                onEdit: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      final text = tester.getRect(find.text("Title"));
      final actions = tester.getRect(find.byType(ItemActionBar));
      if (width < 320) {
        expect(actions.top, greaterThan(text.bottom));
      } else {
        expect(actions.center.dy, text.center.dy);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets("row click, keyboard activation and actions remain independent", (
    tester,
  ) async {
    var opened = 0;
    var edited = 0;
    var deleted = 0;
    await tester.pumpWidget(
      _app(
        AppListCard(
          selected: true,
          title: const Text("Open item"),
          onTap: () => opened++,
          trailing: ItemActionBar.editDelete(
            onEdit: () => edited++,
            onDelete: () => deleted++,
          ),
        ),
      ),
    );
    await tester.tap(find.text("Open item"));
    await tester.tap(find.byTooltip("重新命名"));
    await tester.tap(find.byTooltip("刪除"));
    expect(opened, 1);
    expect(edited, 1);
    expect(deleted, 1);

    // Start focus traversal again at the row's primary InkWell.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened, 2);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _app(
        AppListCard(
          enabled: false,
          title: const Text("Disabled item"),
          onTap: () => opened++,
        ),
      ),
    );
    await tester.tap(find.text("Disabled item"));
    expect(opened, 2);
  });

  testWidgets("draggable cards still accept a drop after another row", (
    tester,
  ) async {
    var dragging = false;
    String? accepted;
    DropPosition? position;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              for (final id in ["First", "Second"])
                DraggableCardNode<String>(
                  key: ValueKey(id),
                  dragData: id,
                  nodeId: id,
                  title: Text(id),
                  isDragging: dragging,
                  isThisDragging: dragging && id == "First",
                  onDragStarted: () => setState(() => dragging = true),
                  onDragEnd: () => setState(() => dragging = false),
                  getDropZoneSize: (pos) => pos == DropPosition.child ? 0 : 0.5,
                  onAccept: (data, pos) {
                    accepted = data;
                    position = pos;
                  },
                ),
            ],
          ),
        ),
      ),
    );
    final target = tester.getRect(find.byKey(const ValueKey("Second")));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text("First")),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    expect(dragging, isTrue);
    await gesture.moveTo(Offset(target.center.dx, target.bottom - 12));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(accepted, "First");
    expect(position, DropPosition.after);
    expect(dragging, isFalse);
    expect(tester.takeException(), isNull);
  });
}
