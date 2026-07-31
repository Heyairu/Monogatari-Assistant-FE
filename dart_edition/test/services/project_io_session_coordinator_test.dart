import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/services/project_io_session_coordinator.dart";

void main() {
  test("serializes project I/O operations", () async {
    final coordinator = ProjectIoSessionCoordinator();
    final session = coordinator.beginSession("project-a");
    final firstGate = Completer<void>();
    final events = <String>[];

    final first = coordinator.run(session, () async {
      events.add("first-start");
      await firstGate.future;
      events.add("first-end");
      return 1;
    });
    final second = coordinator.run(session, () async {
      events.add("second");
      return 2;
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ["first-start"]);
    firstGate.complete();
    expect((await first).value, 1);
    expect((await second).value, 2);
    expect(events, ["first-start", "first-end", "second"]);
  });

  test("drops queued work from an invalidated project session", () async {
    final coordinator = ProjectIoSessionCoordinator();
    final oldSession = coordinator.beginSession("old-project");
    final gate = Completer<void>();
    final first = coordinator.run(oldSession, () async {
      await gate.future;
      return "old";
    });
    final stale = coordinator.run(oldSession, () async => "must-not-run");

    await Future<void>.delayed(Duration.zero);
    coordinator.beginSession("new-project");
    gate.complete();
    expect((await first).value, "old");
    final staleResult = await stale;
    expect(staleResult.didRun, false);
    expect(staleResult.value, isNull);
  });

  test("reuses one prepared payload for the same revision", () async {
    final coordinator = ProjectIoSessionCoordinator();
    final session = coordinator.beginSession("project-a");
    var builds = 0;

    Future<String> payload() => coordinator.sharedPayload<String>(
      token: session,
      revision: 7,
      create: () async => "xml-${++builds}",
    );

    expect(await payload(), "xml-1");
    expect(await payload(), "xml-1");
    expect(builds, 1);
  });
}
