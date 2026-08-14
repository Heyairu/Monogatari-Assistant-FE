import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/domain/models/p2p_revision_models.dart";

const String _projectId = "123e4567-e89b-12d3-a456-426614174000";
const String _deviceA = "223e4567-e89b-12d3-a456-426614174000";
const String _deviceB = "323e4567-e89b-12d3-a456-426614174000";

String _hash(String character) => List<String>.filled(64, character).join();

P2pRevisionMetadata _revision({
  required String id,
  required P2pVersionVector clock,
  required String author,
  List<String> parents = const <String>[],
}) {
  return P2pRevisionMetadata(
    revisionId: id,
    projectUuid: _projectId,
    parents: parents,
    clock: clock,
    authorDeviceId: author,
    createdAtEpochSeconds: 1770000000,
    contentSha256: _hash("f"),
    formatVersion: "1.0",
  );
}

void main() {
  test("version vectors distinguish order from concurrent edits", () {
    final base = P2pVersionVector(<String, int>{_deviceA: 7, _deviceB: 3});
    final newer = P2pVersionVector(<String, int>{_deviceA: 8, _deviceB: 3});
    final concurrent = P2pVersionVector(<String, int>{
      _deviceA: 7,
      _deviceB: 4,
    });

    expect(base.compare(base), P2pVersionVectorRelation.equal);
    expect(newer.compare(base), P2pVersionVectorRelation.dominates);
    expect(base.compare(newer), P2pVersionVectorRelation.dominatedBy);
    expect(newer.compare(concurrent), P2pVersionVectorRelation.concurrent);
    expect(
      newer.merge(concurrent),
      P2pVersionVector(<String, int>{_deviceA: 8, _deviceB: 4}),
    );
  });

  test("revision graph replaces parent heads without losing history", () {
    final first = _revision(
      id: _hash("a"),
      clock: P2pVersionVector(<String, int>{_deviceA: 1}),
      author: _deviceA,
    );
    final second = _revision(
      id: _hash("b"),
      clock: P2pVersionVector(<String, int>{_deviceA: 2}),
      author: _deviceA,
      parents: <String>[first.revisionId],
    );

    final graph = P2pRevisionGraph.empty(
      _projectId,
    ).append(first).append(second);

    expect(graph.revisions, hasLength(2));
    expect(graph.headIds, <String>{second.revisionId});
    expect(graph.singleHead, second);
    expect(P2pRevisionGraph.fromJson(graph.toJson()).headIds, graph.headIds);
  });

  test("revision summaries detect ahead and concurrent heads", () {
    final base = _revision(
      id: _hash("a"),
      clock: P2pVersionVector(<String, int>{_deviceA: 1}),
      author: _deviceA,
    );
    final local = _revision(
      id: _hash("b"),
      clock: P2pVersionVector(<String, int>{_deviceA: 2}),
      author: _deviceA,
    );
    final remote = _revision(
      id: _hash("c"),
      clock: P2pVersionVector(<String, int>{_deviceA: 1, _deviceB: 1}),
      author: _deviceB,
    );
    final baseSummary = P2pRevisionSummary(
      projectUuid: _projectId,
      heads: <P2pRevisionMetadata>[base],
    );
    final localSummary = P2pRevisionSummary(
      projectUuid: _projectId,
      heads: <P2pRevisionMetadata>[local],
    );
    final remoteSummary = P2pRevisionSummary(
      projectUuid: _projectId,
      heads: <P2pRevisionMetadata>[remote],
    );

    expect(
      localSummary.compare(baseSummary),
      P2pRevisionSummaryRelation.localAhead,
    );
    expect(
      baseSummary.compare(localSummary),
      P2pRevisionSummaryRelation.remoteAhead,
    );
    expect(
      localSummary.compare(remoteSummary),
      P2pRevisionSummaryRelation.concurrent,
    );
  });

  test("version vectors reject invalid device IDs and zero counters", () {
    expect(
      () => P2pVersionVector(<String, int>{"device-a": 1}),
      throwsFormatException,
    );
    expect(
      () => P2pVersionVector(<String, int>{_deviceA: 0}),
      throwsFormatException,
    );
  });

  test("revision metadata rejects duplicate parents and graph cycles", () {
    expect(
      () => _revision(
        id: _hash("c"),
        clock: P2pVersionVector(<String, int>{_deviceA: 2}),
        author: _deviceA,
        parents: <String>[_hash("a"), _hash("a")],
      ),
      throwsFormatException,
    );

    final first = _revision(
      id: _hash("a"),
      clock: P2pVersionVector(<String, int>{_deviceA: 1}),
      author: _deviceA,
      parents: <String>[_hash("b")],
    );
    final second = _revision(
      id: _hash("b"),
      clock: P2pVersionVector(<String, int>{_deviceB: 1}),
      author: _deviceB,
      parents: <String>[_hash("a")],
    );
    expect(
      () => P2pRevisionGraph(
        projectUuid: _projectId,
        revisions: <String, P2pRevisionMetadata>{
          first.revisionId: first,
          second.revisionId: second,
        },
        headIds: <String>{first.revisionId},
      ),
      throwsFormatException,
    );
  });

  test("DAG merge preserves branches and finds maximal common ancestor", () {
    final base = _revision(
      id: _hash("a"),
      clock: P2pVersionVector(<String, int>{_deviceA: 1}),
      author: _deviceA,
    );
    final local = _revision(
      id: _hash("b"),
      clock: P2pVersionVector(<String, int>{_deviceA: 2}),
      author: _deviceA,
      parents: <String>[base.revisionId],
    );
    final remote = _revision(
      id: _hash("c"),
      clock: P2pVersionVector(<String, int>{_deviceA: 1, _deviceB: 1}),
      author: _deviceB,
      parents: <String>[base.revisionId],
    );
    final localGraph = P2pRevisionGraph.empty(
      _projectId,
    ).append(base).append(local);
    final remoteGraph = P2pRevisionGraph.empty(
      _projectId,
    ).append(base).append(remote);

    expect(localGraph.commonAncestorIds(remoteGraph), <String>{
      base.revisionId,
    });
    final merged = localGraph.mergedWith(remoteGraph);
    expect(merged.headIds, <String>{local.revisionId, remote.revisionId});
    expect(merged.isAncestorOf(base.revisionId, local.revisionId), isTrue);
    expect(merged.isAncestorOf(local.revisionId, remote.revisionId), isFalse);
  });

  test("revision graph pages resume idempotently and reject replacement", () {
    final base = _revision(
      id: _hash("a"),
      clock: P2pVersionVector(<String, int>{_deviceA: 1}),
      author: _deviceA,
    );
    final child = _revision(
      id: _hash("b"),
      clock: P2pVersionVector(<String, int>{_deviceA: 2}),
      author: _deviceA,
      parents: <String>[base.revisionId],
    );
    final first = P2pRevisionGraphPage(
      projectUuid: _projectId,
      transferId: _hash("d"),
      pageIndex: 0,
      pageCount: 2,
      totalRevisionCount: 2,
      revisions: <P2pRevisionMetadata>[base],
      headIds: <String>{child.revisionId},
    );
    final second = P2pRevisionGraphPage(
      projectUuid: _projectId,
      transferId: _hash("d"),
      pageIndex: 1,
      pageCount: 2,
      totalRevisionCount: 2,
      revisions: <P2pRevisionMetadata>[child],
      headIds: <String>{child.revisionId},
    );
    final assembler = P2pRevisionGraphAssembler()
      ..add(first)
      ..add(first);
    expect(assembler.missingPageIndexes, <int>{1});
    assembler.add(second);
    expect(assembler.assemble().singleHead?.revisionId, child.revisionId);

    final replacement = P2pRevisionGraphPage(
      projectUuid: _projectId,
      transferId: _hash("d"),
      pageIndex: 0,
      pageCount: 2,
      totalRevisionCount: 2,
      revisions: <P2pRevisionMetadata>[child],
      headIds: <String>{child.revisionId},
    );
    expect(() => assembler.add(replacement), throwsFormatException);
  });
}
