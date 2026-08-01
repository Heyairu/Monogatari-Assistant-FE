import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/statusbar.dart";

void main() {
  testWidgets("marquee stops across lifecycle and disposal", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          child: MonogatariStatusBar(
            displayText: "這是一段刻意超出狀態列寬度、用來啟動 marquee 的非常長專案名稱",
            saveTimeText: "12:00",
            cursorLine: 1,
            cursorColumn: 1,
            currentWords: 1,
            totalWords: 1,
            iconSize: 16,
          ),
        ),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
  });
}
