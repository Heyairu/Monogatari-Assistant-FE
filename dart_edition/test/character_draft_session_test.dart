import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/modules/characterview.dart";

void main() {
  test("project switch flushes only the old registered draft", () {
    final coordinator = CharacterDraftSessionCoordinator.instance;
    final oldOwner = Object();
    final newOwner = Object();
    var oldFlushes = 0;
    var newFlushes = 0;

    coordinator.register(
      sessionId: 101,
      owner: oldOwner,
      flush: () => oldFlushes++,
    );
    coordinator.flushAndClose(101);
    coordinator.register(
      sessionId: 102,
      owner: newOwner,
      flush: () => newFlushes++,
    );

    // The old subtree may dispose after the new session has registered.
    coordinator.unregister(sessionId: 101, owner: oldOwner);
    coordinator.flush(101);
    coordinator.flush(102);

    expect(oldFlushes, 1);
    expect(newFlushes, 1);
    expect(coordinator.owns(102, newOwner), isTrue);

    coordinator.flushAndClose(102);
  });

  test("stale owner cannot unregister or flush the active session", () {
    final coordinator = CharacterDraftSessionCoordinator.instance;
    final staleOwner = Object();
    final activeOwner = Object();
    var activeFlushes = 0;

    coordinator.register(sessionId: 201, owner: staleOwner, flush: () {});
    coordinator.register(
      sessionId: 202,
      owner: activeOwner,
      flush: () => activeFlushes++,
    );

    coordinator.unregister(sessionId: 201, owner: staleOwner);
    coordinator.flushAndClose(201);
    coordinator.flush(202);

    expect(activeFlushes, 1);
    expect(coordinator.owns(202, activeOwner), isTrue);

    coordinator.flushAndClose(202);
  });
}
