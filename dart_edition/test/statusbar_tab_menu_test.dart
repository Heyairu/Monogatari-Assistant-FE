import "dart:ui" show PointerDeviceKind;

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/statusbar.dart";

void main() {
  testWidgets(
    "space menu remains clickable through repeated mouse selections",
    (tester) async {
      var count = 2;
      var fullWidth = true;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: MonogatariStatusBar(
                displayText: "正文",
                saveTimeText: "--:--",
                cursorLine: 1,
                cursorColumn: 1,
                currentWords: 0,
                totalWords: 0,
                iconSize: 16,
                tabSpaceCount: count,
                tabFullWidth: fullWidth,
                onTabSpaceCountChanged: (value) =>
                    setState(() => count = value),
                onTabFullWidthChanged: (value) =>
                    setState(() => fullWidth = value),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      Future<void> click(Key key) async {
        final position = tester.getCenter(find.byKey(key));
        await mouse.moveTo(position);
        await mouse.down(position);
        await mouse.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await click(const Key("statusbar-tab-spaces"));
      await click(const Key("tab-half-width-choice"));
      expect(find.text("[半形:2]"), findsOneWidget);
      expect(find.byKey(const Key("tab-half-width-choice")), findsNothing);
      await click(const Key("statusbar-tab-spaces"));
      await click(const Key("tab-space-count-4"));
      expect(find.text("[半形:4]"), findsOneWidget);
      await click(const Key("statusbar-tab-spaces"));
      await click(const Key("tab-full-width-choice"));
      expect(find.text("[全形:4]"), findsOneWidget);
      await mouse.removePointer();
    },
  );
}
