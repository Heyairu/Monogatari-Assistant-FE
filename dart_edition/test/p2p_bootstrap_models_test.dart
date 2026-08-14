import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/domain/models/p2p_bootstrap_models.dart";
import "package:monogatari_assistant/domain/models/p2p_revision_models.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";

const String _projectId = "123e4567-e89b-12d3-a456-426614174000";
const String _deviceA = "223e4567-e89b-12d3-a456-426614174000";
const String _deviceB = "323e4567-e89b-12d3-a456-426614174000";
const String _deviceC = "423e4567-e89b-12d3-a456-426614174000";
const String _joiningDevice = "523e4567-e89b-12d3-a456-426614174000";

String _hash(String character) => List<String>.filled(64, character).join();

P2pRevisionMetadata _head({
  String revisionCharacter = "a",
  String contentCharacter = "f",
  int createdAt = 1770000000,
}) {
  return P2pRevisionMetadata(
    revisionId: _hash(revisionCharacter),
    projectUuid: _projectId,
    parents: const <String>[],
    clock: P2pVersionVector(const <String, int>{_deviceA: 1}),
    authorDeviceId: _deviceA,
    createdAtEpochSeconds: createdAt,
    contentSha256: _hash(contentCharacter),
    formatVersion: "1.0",
  );
}

P2pSnapshotManifest _manifest(
  P2pRevisionMetadata head, {
  int contentLength = 4096,
}) {
  return P2pSnapshotManifest(
    projectUuid: head.projectUuid,
    revisionId: head.revisionId,
    contentSha256: head.contentSha256,
    contentLength: contentLength,
    formatVersion: head.formatVersion,
  );
}

P2pBootstrapPeerReply _reply(
  String peerDeviceId, {
  P2pRevisionMetadata? head,
  P2pSnapshotManifest? manifest,
}) {
  final resolvedHead = head ?? _head();
  return P2pBootstrapPeerReply(
    peerDeviceId: peerDeviceId,
    summary: P2pRevisionSummary(
      projectUuid: resolvedHead.projectUuid,
      heads: <P2pRevisionMetadata>[resolvedHead],
    ),
    headManifest: manifest ?? _manifest(resolvedHead),
  );
}

void main() {
  const planner = P2pBootstrapConsensusPlanner();

  test("two original peers with one exact head produce a ready plan", () {
    final decision = planner.plan(
      joiningDeviceId: _joiningDevice,
      originalPeerDeviceIds: const <String>[_deviceB, _deviceA],
      observations: <P2pBootstrapPeerObservation>[
        _reply(_deviceB),
        _reply(_deviceA),
      ],
    );

    expect(decision, isA<P2pBootstrapReady>());
    final ready = decision as P2pBootstrapReady;
    expect(ready.projectUuid, _projectId);
    expect(ready.sourcePeerDeviceId, _deviceA);
    expect(ready.confirmingPeerDeviceIds, <String>{_deviceA, _deviceB});
    expect(ready.manifest.contentSha256, _hash("f"));
    expect(
      () => ready.confirmingPeerDeviceIds.add(_deviceC),
      throwsUnsupportedError,
    );
  });

  test("a group with fewer than two original peers is not eligible", () {
    final decision = planner.plan(
      joiningDeviceId: _joiningDevice,
      originalPeerDeviceIds: const <String>[_deviceA],
      observations: <P2pBootstrapPeerObservation>[_reply(_deviceA)],
    );

    expect(decision, isA<P2pBootstrapNotEligible>());
    expect((decision as P2pBootstrapNotEligible).originalPeerCount, 1);
  });

  test("missing, unreachable, or unverifiable peers block bootstrap", () {
    final missing = planner.plan(
      joiningDeviceId: _joiningDevice,
      originalPeerDeviceIds: const <String>[_deviceA, _deviceB],
      observations: <P2pBootstrapPeerObservation>[_reply(_deviceA)],
    );
    expect(
      (missing as P2pBootstrapSourceUnavailable).unavailablePeerDeviceIds,
      <String>{_deviceB},
    );

    final unreachable = planner.plan(
      joiningDeviceId: _joiningDevice,
      originalPeerDeviceIds: const <String>[_deviceA, _deviceB],
      observations: <P2pBootstrapPeerObservation>[
        _reply(_deviceA),
        P2pBootstrapPeerUnavailable(
          peerDeviceId: _deviceB,
          reason: P2pBootstrapPeerUnavailableReason.unreachable,
        ),
      ],
    );
    expect(unreachable, isA<P2pBootstrapSourceUnavailable>());

    final mismatchedHead = _head(revisionCharacter: "b");
    final unverifiable = planner.plan(
      joiningDeviceId: _joiningDevice,
      originalPeerDeviceIds: const <String>[_deviceA, _deviceB],
      observations: <P2pBootstrapPeerObservation>[
        _reply(_deviceA),
        _reply(_deviceB, head: mismatchedHead, manifest: _manifest(_head())),
      ],
    );
    expect(
      (unverifiable as P2pBootstrapSourceUnavailable).unavailablePeerDeviceIds,
      <String>{_deviceB},
    );
  });

  test("different heads or contradictory metadata produce a conflict", () {
    final differentHead = _head(revisionCharacter: "b", contentCharacter: "e");
    final differentRevision = planner.plan(
      joiningDeviceId: _joiningDevice,
      originalPeerDeviceIds: const <String>[_deviceA, _deviceB],
      observations: <P2pBootstrapPeerObservation>[
        _reply(_deviceA),
        _reply(_deviceB, head: differentHead),
      ],
    );
    expect(
      (differentRevision as P2pBootstrapConflict).conflictingPeerDeviceIds,
      <String>{_deviceA, _deviceB},
    );

    final contradictoryHead = _head(createdAt: 1770000001);
    final contradictoryMetadata = planner.plan(
      joiningDeviceId: _joiningDevice,
      originalPeerDeviceIds: const <String>[_deviceA, _deviceB],
      observations: <P2pBootstrapPeerObservation>[
        _reply(_deviceA),
        _reply(_deviceB, head: contradictoryHead),
      ],
    );
    expect(contradictoryMetadata, isA<P2pBootstrapConflict>());
  });

  test("multiple heads produce a conflict instead of selecting one", () {
    final firstHead = _head();
    final secondHead = _head(revisionCharacter: "b", contentCharacter: "e");
    final decision = planner.plan(
      joiningDeviceId: _joiningDevice,
      originalPeerDeviceIds: const <String>[_deviceA, _deviceB],
      observations: <P2pBootstrapPeerObservation>[
        P2pBootstrapPeerReply(
          peerDeviceId: _deviceA,
          summary: P2pRevisionSummary(
            projectUuid: _projectId,
            heads: <P2pRevisionMetadata>[firstHead, secondHead],
          ),
          headManifest: _manifest(firstHead),
        ),
        _reply(_deviceB),
      ],
    );

    expect(decision, isA<P2pBootstrapConflict>());
  });

  test("duplicate roster and observations fail closed", () {
    expect(
      () => planner.plan(
        joiningDeviceId: _joiningDevice,
        originalPeerDeviceIds: const <String>[_deviceA, _deviceA],
        observations: const <P2pBootstrapPeerObservation>[],
      ),
      throwsFormatException,
    );
    final duplicateReply = _reply(_deviceA);
    expect(
      () => planner.plan(
        joiningDeviceId: _joiningDevice,
        originalPeerDeviceIds: const <String>[_deviceA, _deviceB],
        observations: <P2pBootstrapPeerObservation>[
          duplicateReply,
          duplicateReply,
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => planner.plan(
        joiningDeviceId: _joiningDevice,
        originalPeerDeviceIds: const <String>[_deviceA, _deviceB],
        observations: <P2pBootstrapPeerObservation>[_reply(_deviceC)],
      ),
      throwsFormatException,
    );
    expect(
      () => planner.plan(
        joiningDeviceId: _deviceA,
        originalPeerDeviceIds: const <String>[_deviceA, _deviceB],
        observations: const <P2pBootstrapPeerObservation>[],
      ),
      throwsFormatException,
    );
  });

  test("the original peer roster has a strict upper bound", () {
    final oversizedRoster = List<String>.generate(
      P2pBootstrapConsensusPlanner.maxOriginalPeerCount + 1,
      (index) =>
          "00000000-0000-4000-8000-${index.toRadixString(16).padLeft(12, "0")}",
      growable: false,
    );

    expect(
      () => planner.plan(
        joiningDeviceId: _joiningDevice,
        originalPeerDeviceIds: oversizedRoster,
        observations: const <P2pBootstrapPeerObservation>[],
      ),
      throwsFormatException,
    );
  });
}
