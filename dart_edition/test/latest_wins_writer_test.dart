import "dart:async";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/utils/latest_wins_writer.dart";

void main() {
  test(
    "serial writer coalesces in-flight updates to the newest snapshot",
    () async {
      final writes = <String>[];
      final gates = <Completer<void>>[];
      final writer = LatestWinsWriter(
        write: (content) {
          writes.add(content);
          final gate = Completer<void>();
          gates.add(gate);
          return gate.future;
        },
      );

      writer.schedule(() => "old", immediate: true);
      await Future<void>.delayed(Duration.zero);
      writer.schedule(() => "middle", immediate: true);
      writer.schedule(() => "newest", immediate: true);
      expect(writes, <String>["old"]);

      gates.first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(writes, <String>["old", "newest"]);

      gates.last.complete();
      await writer.close();
      expect(writes, <String>["old", "newest"]);
    },
  );

  testWidgets("idle debounce performs one write", (tester) async {
    final writes = <String>[];
    final writer = LatestWinsWriter(
      debounce: const Duration(milliseconds: 100),
      write: (content) async => writes.add(content),
    );

    writer.schedule(() => "a");
    writer.schedule(() => "b");
    await tester.pump(const Duration(milliseconds: 99));
    expect(writes, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(writes, <String>["b"]);
    await writer.close();
  });

  test("atomic writer replaces an existing file", () async {
    final directory = await Directory.systemTemp.createTemp(
      "monogatari-writer-test-",
    );
    addTearDown(() => directory.delete(recursive: true));
    final target = File("${directory.path}${Platform.pathSeparator}notes.json");
    await target.writeAsString("old");

    await writeTextAtomically(target, "new");

    expect(await target.readAsString(), "new");
    expect(await File("${target.path}.tmp").exists(), isFalse);
  });
}
